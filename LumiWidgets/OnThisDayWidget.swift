import WidgetKit
import SwiftUI

/// 「去年今日」匹配：在给定参考日，挑出往年同一日（附近）的一条回忆。
enum OnThisDay {

    /// 在 `reference` 当天，挑「往年今日」最贴近的一条回忆。
    /// 规则：只看比参考日更早**年份**的足迹；按距「今日」的天数差（跨年环绕）取最近，
    /// 同样近则偏向更近的年份（去年优先于前年）。超出窗口（默认 ±4 天）视为无。
    static func memory(for reference: Date,
                       from memories: [LumiMemory],
                       windowDays: Int = 4) -> LumiMemory? {
        let cal = Calendar.current
        let refYear = cal.component(.year, from: reference)
        guard let refDoy = cal.ordinality(of: .day, in: .year, for: reference) else { return nil }

        func dayDistance(_ m: LumiMemory) -> Int {
            guard let doy = cal.ordinality(of: .day, in: .year, for: m.visitedAt) else { return .max }
            let raw = abs(doy - refDoy)
            return min(raw, 366 - raw)   // 12-31 ↔ 01-01 跨年环绕
        }

        return memories
            .filter { cal.component(.year, from: $0.visitedAt) < refYear }
            .filter { dayDistance($0) <= windowDays }
            .min { a, b in
                let da = dayDistance(a), db = dayDistance(b)
                if da != db { return da < db }
                return a.visitedAt > b.visitedAt
            }
    }
}

/// 时间线条目：某一天 + 当天匹配到的回忆 + 星图点位（统一品牌肌理用）。
struct OnThisDayEntry: TimelineEntry {
    let date: Date
    let memory: LumiMemory?
    var litCountryCodes: [String] = []
}

/// Provider：生成未来若干天的每日条目，让小组件每天自动滚动到「那天的去年今日」，
/// 即使期间没打开 App 也能换内容（policy `.atEnd` 到期再续）。
struct OnThisDayProvider: TimelineProvider {

    private let lookaheadDays = 7

    func placeholder(in context: Context) -> OnThisDayEntry {
        OnThisDayEntry(date: Date(), memory: Self.previewMemory())
    }

    func getSnapshot(in context: Context, completion: @escaping (OnThisDayEntry) -> Void) {
        if context.isPreview {
            let m = Self.previewMemory()
            completion(OnThisDayEntry(date: Date(), memory: m, litCountryCodes: [m.countryCode ?? "AE"]))
            return
        }
        let snap = LumiSnapshotStore.load()
        completion(OnThisDayEntry(date: Date(),
                                  memory: OnThisDay.memory(for: Date(), from: snap.memories),
                                  litCountryCodes: snap.litCountryCodes))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OnThisDayEntry>) -> Void) {
        let snap = LumiSnapshotStore.load()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        var entries: [OnThisDayEntry] = []
        for offset in 0..<lookaheadDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            // 第 0 天用「现在」作为生效时间，确保立即可见；其余落在当日零点。
            let effectiveDate = offset == 0 ? Date() : day
            entries.append(OnThisDayEntry(date: effectiveDate,
                                          memory: OnThisDay.memory(for: day, from: snap.memories),
                                          litCountryCodes: snap.litCountryCodes))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// 画廊预览：合成一条「去年今日」回忆（与产品示意图一致）。
    private static func previewMemory() -> LumiMemory {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return LumiMemory(visitedAt: oneYearAgo, placeName: "迪拜",
                          countryName: "阿拉伯联合酋长国", countryCode: "AE",
                          mood: "塔顶看落日，风是热的")
    }
}

/// 「去年今日」主屏 / 锁屏小组件。
struct OnThisDayWidget: Widget {
    static let kind = "OnThisDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: OnThisDayProvider()) { entry in
            OnThisDayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetTheme.bgGradient }
        }
        .configurationDisplayName("去年今日")
        .description("每天回看往年同一天，你曾在世界的哪个角落。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
