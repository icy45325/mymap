import WidgetKit
import SwiftUI
import AppIntents

/// 可配置展示模式：添加小组件后，长按 → 编辑小组件 → 切换「点亮战绩 / 去过的国旗」。
enum LumiWidgetMode: String, AppEnum {
    case stats
    case flags

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "展示模式" }
    static var caseDisplayRepresentations: [LumiWidgetMode: DisplayRepresentation] {
        [
            .stats: DisplayRepresentation(title: "点亮战绩"),
            .flags: DisplayRepresentation(title: "去过的国旗"),
        ]
    }
}

/// 小组件配置 Intent（提供模式选择参数）。
struct LumiWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Lumi 小组件"
    static var description = IntentDescription("选择小组件展示模式。")

    @Parameter(title: "模式", default: .stats)
    var mode: LumiWidgetMode
}

struct LumiEntry: TimelineEntry {
    let date: Date
    let snapshot: LumiSnapshot
    let mode: LumiWidgetMode
}

struct LumiProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LumiEntry {
        LumiEntry(date: Date(), snapshot: .sample, mode: .stats)
    }
    func snapshot(for configuration: LumiWidgetConfig, in context: Context) async -> LumiEntry {
        let snap = context.isPreview ? .sample : LumiSnapshotStore.load()
        return LumiEntry(date: Date(), snapshot: snap, mode: configuration.mode)
    }
    func timeline(for configuration: LumiWidgetConfig, in context: Context) async -> Timeline<LumiEntry> {
        let entry = LumiEntry(date: Date(), snapshot: LumiSnapshotStore.load(), mode: configuration.mode)
        return Timeline(entries: [entry], policy: .never)   // 由主 App 在数据变更时主动刷新
    }
}

/// 「Lumi 战绩」主屏小组件——一个小组件，模式可切（战绩 / 国旗）。
struct LumiWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: LumiAppGroup.widgetKind,
                               intent: LumiWidgetConfig.self,
                               provider: LumiProvider()) { entry in
            Group {
                switch entry.mode {
                case .stats: LitCountWidgetView(snapshot: entry.snapshot)
                case .flags: FlagWidgetView(snapshot: entry.snapshot)
                }
            }
            .containerBackground(for: .widget) { WidgetTheme.bgGradient }
        }
        .configurationDisplayName("Lumi 战绩")
        .description("点亮战绩 / 去过的国旗，添加后可在「编辑小组件」里切换。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
