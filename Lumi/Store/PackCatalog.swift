import SwiftUI
import os.log

// ─────────────────────────────────────────────────────────────
//  PackCatalog —— 资源包目录加载器（v1.15 商店地基）。
//
//  · v1.15：只读 Bundle 里的 StorePacks.json（本文件唯一数据源，纯本地零网络）；
//  · v1.2 ：换成「远程 manifest → 本地缓存 → 校验」的加载器，本类接口不变；
//  · 三条协议级不变量见 ARCHITECTURE §4.1：raw 只增不改 / 接收端降级 / manifest 同构。
// ─────────────────────────────────────────────────────────────

@MainActor
final class PackCatalog: ObservableObject {
    static let shared = PackCatalog()

    /// 已加载且当前 App 版本可见的包（minAppVersion 过滤后）。
    /// 基础 = Bundle 内置；D2「增值远程」= remote manifest 里的**新增包**合并进来（同 id 以远程为准）。
    @Published private(set) var packs: [ContentPack]

    private init() {
        packs = Self.loadBundleManifest()
        #if DEBUG
        Self.validateAgainstCodeCatalogs(packs)
        #endif
    }

    /// 拉远程 manifest（Supabase Storage 公共桶 `packs/index.json`）合并增值包。
    /// 未配置后端 / 拉取失败 → 静默保持内置目录（商店永不白屏）。
    func refreshRemote() async {
        guard let base = LumiPostConfig.url else { return }
        guard let url = URL(string: base.absoluteString + "/storage/v1/object/public/packs/index.json")
        else { return }
        var req = URLRequest(url: url); req.timeoutInterval = 20
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let manifest = try? JSONDecoder().decode(PackManifest.self, from: data) else { return }
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        let remote = manifest.packs.filter { p in
            guard let min = p.minAppVersion else { return true }
            return appVersion.compare(min, options: .numeric) != .orderedAscending
        }
        var merged = packs.filter { local in !remote.contains(where: { $0.id == local.id }) }
        merged.append(contentsOf: remote)
        packs = merged
    }

    // MARK: - 查询

    func pack(_ id: String) -> ContentPack? { packs.first { $0.id == id } }

    func item(pack packID: String, id itemID: String) -> PackItem? {
        pack(packID)?.items.first { $0.id == itemID }
    }

    /// 解析 `pack:<packID>/<itemID>` raw；不认识返回 nil（渲染侧降级，raw 原样保留在存储）。
    func item(raw: String) -> (pack: ContentPack, item: PackItem)? {
        guard raw.hasPrefix("pack:") else { return nil }
        let body = raw.dropFirst(5)
        guard let slash = body.firstIndex(of: "/") else { return nil }
        let packID = String(body[..<slash])
        let itemID = String(body[body.index(after: slash)...])
        guard let p = pack(packID), let i = p.items.first(where: { $0.id == itemID }) else { return nil }
        return (p, i)
    }

    /// 某分类下的包（货架/图鉴用）。
    func packs(in category: PackCategory) -> [ContentPack] { packs.filter { $0.category == category } }

    // MARK: - 加载

    private static func loadBundleManifest() -> [ContentPack] {
        guard let url = Bundle.main.url(forResource: "StorePacks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(PackManifest.self, from: data) else {
            Logger(subsystem: "com.lumi.v0", category: "store")
                .warning("StorePacks.json 缺失或解析失败——资源包目录为空（不影响既有邮票）")
            return []
        }
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        return manifest.packs.filter { p in
            guard let min = p.minAppVersion else { return true }
            return appVersion.compare(min, options: .numeric) != .orderedAscending
        }
    }

    #if DEBUG
    /// 一致性自检：manifest 镜像条目应与代码目录逐一对应（只警告不崩溃，供开发期发现漂移）。
    private static func validateAgainstCodeCatalogs(_ packs: [ContentPack]) {
        let log = Logger(subsystem: "com.lumi.v0", category: "store")
        let mirrored = packs.flatMap(\.items).compactMap(\.legacyRaw)
        let expected = RegionalStamp.all.map(\.raw)
            + PremiumStamp.all.map(\.raw)
            + Festival.allCases.map { "fest:\($0.rawValue)" }
        for raw in expected where !mirrored.contains(raw) {
            log.warning("manifest 缺少代码目录条目镜像：\(raw, privacy: .public)")
        }
        for raw in mirrored where !expected.contains(raw) && raw != "postmark" {
            log.warning("manifest 镜像了不存在的代码条目：\(raw, privacy: .public)")
        }
    }
    #endif
}

// MARK: - pack 条目渲染

/// `StampKind.pack` 的渲染视图：图票直接贴图；code-drawn 走渲染器注册表；
/// 目录里找不到（未装包/未知包）→ 回落基础空运票（raw 仍原样存储，装包后自动还原）。
struct PackItemStampView: View {
    let packID: String
    let itemID: String
    var mini: Bool = false

    var body: some View {
        if let item = PackCatalog.shared.item(pack: packID, id: itemID) {
            switch item.render.type {
            case "image":
                if let asset = item.render.asset {
                    if asset.hasPrefix("http") {
                        RemotePackImage(url: asset, mini: mini)     // 远程图票（增值包）
                    } else {
                        Image(asset).resizable().scaledToFit()      // 内置 imageset
                            .shadow(color: .black.opacity(0.25), radius: mini ? 1 : 2, y: 1)
                    }
                } else { fallback }
            case "coded":
                CodedStampRenderer.view(id: item.render.renderer, mini: mini)
            default:
                fallback
            }
        } else {
            fallback
        }
    }

    private var fallback: some View { PostcardStampView(stamp: .air, mini: mini) }
}

/// 远程图票：磁盘缓存优先（保证 ImageRenderer 同步导出可用），未命中即下载后缓存。
struct RemotePackImage: View {
    let url: String
    var mini: Bool = false
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let ui = image ?? PackImageCache.cached(url) {
                Image(uiImage: ui).resizable().scaledToFit()
                    .shadow(color: .black.opacity(0.25), radius: mini ? 1 : 2, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.15))
                    .overlay(ProgressView().scaleEffect(0.5))
                    .task { image = await PackImageCache.fetch(url) }
            }
        }
    }
}

/// 远程票图缓存：Caches/lumi-packs/<sha 简化名>；一次下载永久复用（包版本更新换 URL）。
enum PackImageCache {
    private static var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lumi-packs", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private static func file(_ url: String) -> URL {
        // 稳定哈希（FNV-1a）：String.hashValue 每次启动随机化，不能做缓存文件名
        var h: UInt64 = 0xcbf29ce484222325
        for b in url.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return dir.appendingPathComponent(String(h, radix: 36) + ".img")
    }
    static func cached(_ url: String) -> UIImage? {
        guard let data = try? Data(contentsOf: file(url)) else { return nil }
        return UIImage(data: data)
    }
    static func fetch(_ url: String) async -> UIImage? {
        if let hit = cached(url) { return hit }
        guard let u = URL(string: url),
              let (data, resp) = try? await URLSession.shared.data(from: u),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let ui = UIImage(data: data) else { return nil }
        try? data.write(to: file(url))
        return ui
    }
}

/// code-drawn 渲染器注册表：manifest 用 id 引用 SwiftUI 手绘票（美术零打包成本）。
enum CodedStampRenderer {
    @ViewBuilder
    static func view(id: String?, mini: Bool) -> some View {
        if let id, id.hasPrefix("regional:"),
           let r = RegionalStamp.byCodeAnywhere(String(id.dropFirst(9))) {
            RegionalStampView(stamp: r, mini: mini)
        } else {
            PostcardStampView(stamp: .air, mini: mini)   // 未知渲染器 → 降级
        }
    }
}
