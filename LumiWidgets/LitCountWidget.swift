import WidgetKit
import SwiftUI

/// 时间线条目：一份快照即一帧。
struct LitCountEntry: TimelineEntry {
    let date: Date
    let snapshot: LumiSnapshot
}

/// Provider：只从 App Group 读快照。刷新由主 App 在数据变更时
/// `reloadTimelines(ofKind:)` 主动触发，故策略用 `.never`（不耗系统预算空转）。
struct LitCountProvider: TimelineProvider {

    func placeholder(in context: Context) -> LitCountEntry {
        LitCountEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (LitCountEntry) -> Void) {
        let snap = context.isPreview ? .sample : LumiSnapshotStore.load()
        completion(LitCountEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LitCountEntry>) -> Void) {
        let entry = LitCountEntry(date: Date(), snapshot: LumiSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

/// 「点亮战绩」主屏 / 锁屏小组件。
struct LitCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LumiAppGroup.widgetKind, provider: LitCountProvider()) { entry in
            LitCountWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.bgGradient }
        }
        .configurationDisplayName("点亮战绩")
        .description("不打开 App 也能看到你点亮了多少个国家。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
