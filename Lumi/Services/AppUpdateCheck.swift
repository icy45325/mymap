import Foundation

/// 新版本检测——**零后端**，用 Apple 公共 iTunes Lookup 接口查 App Store 最新版本。
///
/// `GET https://itunes.apple.com/lookup?bundleId=<id>` → `results[0].version` + `trackViewUrl`。
/// bundleId 取运行时 `Bundle.main.bundleIdentifier`（自动跟随签名 ID）。比本机版本高且未被「跳过」→ 提示更新。
/// 纯 GET、不上传任何用户数据 → 隐私标签仍「Data Not Collected」；HTTPS 合规，无需改 ATS。
/// 首版未上架时 lookup 返回 `resultCount: 0` → 静默无操作。
@MainActor
final class AppUpdateCheck: ObservableObject {
    static let shared = AppUpdateCheck()

    struct AppUpdate: Equatable {
        let version: String
        let url: URL
    }

    /// 有更新且未被跳过时为非 nil；驱动 UI 弹窗 / 设置页版本行。
    @Published private(set) var available: AppUpdate?

    /// 本机版本（`CFBundleShortVersionString`，即 Xcode `MARKETING_VERSION`）。
    let currentVersion: String

    private let store = UserDefaults.standard
    private let kLastCheck = "lumi.update.lastCheckAt"
    private let kSkipped = "lumi.update.skippedVersion"
    private let throttle: TimeInterval = 60 * 60 * 24   // 24h 内不重复查

    private init() {
        currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// 启动 / 进设置页调用。`force` 跳过 24h 节流（设置页主动刷新用）。
    func check(force: Bool = false) async {
        if !force {
            let last = store.double(forKey: kLastCheck)
            if last > 0, Date().timeIntervalSince1970 - last < throttle { return }
        }
        store.set(Date().timeIntervalSince1970, forKey: kLastCheck)

        guard let bundleID = Bundle.main.bundleIdentifier,
              var comps = URLComponents(string: "https://itunes.apple.com/lookup") else { return }
        comps.queryItems = [URLQueryItem(name: "bundleId", value: bundleID)]
        guard let url = comps.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(LookupResult.self, from: data)
            guard let entry = result.results.first else { return }   // 未上架 → 空 → 静默
            if Self.isNewer(entry.version, than: currentVersion),
               entry.version != store.string(forKey: kSkipped),
               let storeURL = URL(string: entry.trackViewUrl) {
                available = AppUpdate(version: entry.version, url: storeURL)
            } else {
                available = nil
            }
        } catch {
            // 离线 / 解析失败 → 静默，不打扰
        }
    }

    /// 用户「跳过此版本」：该版本不再提示。
    func skip(_ version: String) {
        store.set(version, forKey: kSkipped)
        available = nil
    }

    /// 仅关闭当前提示（「稍后」），不记跳过——下次满足条件仍会提示。
    func dismiss() { available = nil }

    /// 语义版本比较：按 `.` 拆段、缺位补 0、逐段数值比较。`a` 是否高于 `b`。
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - 解码

    private struct LookupResult: Decodable {
        let results: [Entry]
        struct Entry: Decodable {
            let version: String
            let trackViewUrl: String
        }
    }
}
