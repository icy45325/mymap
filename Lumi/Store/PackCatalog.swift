import SwiftUI
import os.log

// ─────────────────────────────────────────────────────────────
//  PackCatalog —— 资源包目录加载器（v1.15 商店地基）。
//
//  · v1.15：只读 Bundle 里的 StorePacks.json（本文件唯一数据源，纯本地零网络）；
//  · v1.2 ：换成「远程 manifest → 本地缓存 → 校验」的加载器，本类接口不变；
//  · 三条协议级不变量见 ARCHITECTURE §4.1：raw 只增不改 / 接收端降级 / manifest 同构。
// ─────────────────────────────────────────────────────────────

final class PackCatalog {
    static let shared = PackCatalog()

    /// 已加载且当前 App 版本可见的包（minAppVersion 过滤后）。
    let packs: [ContentPack]

    private init() {
        packs = Self.loadBundleManifest()
        #if DEBUG
        Self.validateAgainstCodeCatalogs(packs)
        #endif
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
                    Image(asset).resizable().scaledToFit()
                        .shadow(color: .black.opacity(0.25), radius: mini ? 1 : 2, y: 1)
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

/// code-drawn 渲染器注册表：manifest 用 id 引用 SwiftUI 手绘票（美术零打包成本）。
enum CodedStampRenderer {
    @ViewBuilder
    static func view(id: String?, mini: Bool) -> some View {
        if let id, id.hasPrefix("regional:"),
           let r = RegionalStamp.byCode(String(id.dropFirst(9))) {
            RegionalStampView(stamp: r, mini: mini)
        } else {
            PostcardStampView(stamp: .air, mini: mini)   // 未知渲染器 → 降级
        }
    }
}
