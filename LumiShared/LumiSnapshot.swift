import Foundation

// ─────────────────────────────────────────────────────────────
//  App ↔ 小组件 的共享快照层。
//
//  小组件是独立进程，读不到主 App 的 SwiftData 沙盒。约定：主 App 在
//  「点亮 / 启动 / 删除」等数据变更后，把一份极小的派生快照写进 App Group
//  的 UserDefaults；小组件只读这份快照渲染，不碰数据库。
//
//  本文件**纯 Foundation、无任何 App 依赖**，同时编译进 Lumi 与 LumiWidgets
//  两个 target（见工程的 LumiShared 同步组）。
// ─────────────────────────────────────────────────────────────

/// 一条精简回忆：供「去年今日」小组件按日期回看（不放照片 / 同行人，隐私 + 体积）。
struct LumiMemory: Codable, Equatable {
    var visitedAt: Date
    var placeName: String        // 城市 ?? 地点名
    var countryName: String?     // 中文国名
    var countryCode: String?     // ISO_A2，用于国旗
    var mood: String?            // 一句心情（可空）
}

/// 喂给小组件的派生快照：只放展示要用的标量 / 精简回忆，不放足迹原文（隐私 + 体积）。
struct LumiSnapshot: Codable, Equatable {

    /// 已点亮国家数（distinct countryCode）。
    var countries: Int
    /// 已点亮城市数（distinct cityName）。
    var cities: Int
    /// 占世界国家总数的百分比（已四舍五入取整）。
    var worldPercent: Int
    /// 已点亮国家码集合，用于小组件星图点位的稳定布局。
    var litCountryCodes: [String]

    /// 最近一次点亮的地点 / 国家 / 日期（用于副标题「上次你在…」）。
    var lastPlaceName: String?
    var lastCountryName: String?
    var lastVisitedAt: Date?

    /// 全部足迹的精简回忆（按 visitedAt 升序），供「去年今日」按日期匹配。
    var memories: [LumiMemory]

    /// 快照生成时间（调试 / 兜底刷新判断用）。
    var updatedAt: Date

    /// 空态：尚无任何点亮。
    static let empty = LumiSnapshot(
        countries: 0, cities: 0, worldPercent: 0, litCountryCodes: [],
        lastPlaceName: nil, lastCountryName: nil, lastVisitedAt: nil,
        memories: [], updatedAt: .distantPast)

    /// 小组件画廊 / 预览占位（与产品示意图一致：9 国 · 5%）。
    static let sample = LumiSnapshot(
        countries: 9, cities: 23, worldPercent: 5,
        litCountryCodes: ["AE", "CN", "JP", "FR", "GB", "US", "TH", "SG", "IT"],
        lastPlaceName: "迪拜", lastCountryName: "阿拉伯联合酋长国", lastVisitedAt: nil,
        memories: [], updatedAt: .distantPast)
}

/// App Group 常量（主 App 与小组件共用同一套标识）。
enum LumiAppGroup {
    /// App Group 容器标识；主 App 与小组件的 entitlements 都要声明它。
    static let id = "group.com.lumi.fun"
    /// 快照在共享 UserDefaults 里的键（v2 起含 memories；快照全派生，升级即由 App 重写）。
    static let snapshotKey = "lumi.snapshot.v2"
    /// 小组件 kind（StaticConfiguration / reloadTimelines(ofKind:) 共用）。
    static let widgetKind = "LitCountWidget"
    /// 国旗集合小组件 kind。
    static let flagWidgetKind = "LumiFlagWidget"
}

/// 共享快照的读写入口（App Group UserDefaults，JSON 编码）。
enum LumiSnapshotStore {

    private static var defaults: UserDefaults? { UserDefaults(suiteName: LumiAppGroup.id) }

    /// 写入快照（主 App 侧调用）。App Group 不可用时静默跳过，不崩。
    static func save(_ snapshot: LumiSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: LumiAppGroup.snapshotKey)
    }

    /// 读取快照（小组件侧调用）；无数据 / 解析失败回退到空态。
    static func load() -> LumiSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: LumiAppGroup.snapshotKey),
              let snapshot = try? JSONDecoder().decode(LumiSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
