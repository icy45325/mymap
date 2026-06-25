import WidgetKit
import SwiftUI

/// 国旗集合小组件：展示去过国家的国旗（最多 5 个）。

struct FlagEntry: TimelineEntry {
    let date: Date
    let snapshot: LumiSnapshot
}

struct FlagProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlagEntry {
        FlagEntry(date: Date(), snapshot: .sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (FlagEntry) -> Void) {
        completion(FlagEntry(date: Date(), snapshot: context.isPreview ? .sample : LumiSnapshotStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlagEntry>) -> Void) {
        completion(Timeline(entries: [FlagEntry(date: Date(), snapshot: LumiSnapshotStore.load())], policy: .never))
    }
}

struct FlagWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LumiAppGroup.flagWidgetKind, provider: FlagProvider()) { entry in
            FlagWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.bgGradient }
        }
        .configurationDisplayName("去过的国旗")
        .description("展示你去过国家的国旗集合（最多 5 个）。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FlagWidgetView: View {
    let snapshot: LumiSnapshot
    @Environment(\.widgetFamily) private var family

    private var maxFlags: Int { family == .systemSmall ? 4 : 5 }
    private var flags: [String] { snapshot.litCountryCodes.prefix(maxFlags).map(flagEmoji) }
    private var overflow: Int { max(0, snapshot.countries - flags.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(section: "去过的国旗")
            if flags.isEmpty {
                Spacer()
                Text("还没有点亮国家")
                    .font(.system(size: 12)).foregroundStyle(WidgetTheme.muted)
                Spacer()
            } else {
                Spacer(minLength: 0)
                HStack(spacing: family == .systemSmall ? 4 : 8) {
                    ForEach(Array(flags.enumerated()), id: \.offset) { _, f in
                        Text(f).font(.system(size: family == .systemSmall ? 30 : 40))
                    }
                    if overflow > 0 {
                        Text("+\(overflow)")
                            .font(.system(size: family == .systemSmall ? 15 : 18, weight: .bold))
                            .foregroundStyle(WidgetTheme.orange)
                    }
                }
                Spacer(minLength: 0)
                Text("已点亮 \(snapshot.countries) 国")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetTheme.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(WidgetChrome.pad)
    }
}
