import WidgetKit
import SwiftUI

/// 独立「去过的国旗」小组件：可直接从小组件库添加，无需进「编辑小组件」切模式。
/// 与 `LumiWidget` 的「国旗」模式共用同一视图与快照。
struct FlagWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LumiAppGroup.flagWidgetKind, provider: FlagProvider()) { entry in
            FlagWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WidgetTheme.bgGradient }
        }
        .configurationDisplayName("去过的国旗")
        .description("展示去过国家的国旗集合。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FlagEntry: TimelineEntry {
    let date: Date
    let snapshot: LumiSnapshot
}

struct FlagProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlagEntry { FlagEntry(date: Date(), snapshot: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (FlagEntry) -> Void) {
        completion(FlagEntry(date: Date(), snapshot: context.isPreview ? .sample : LumiSnapshotStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlagEntry>) -> Void) {
        // 由主 App 在数据变更时主动 reloadAllTimelines；这里给单点时间线。
        completion(Timeline(entries: [FlagEntry(date: Date(), snapshot: LumiSnapshotStore.load())], policy: .never))
    }
}

/// 国旗集合视图：小尺寸＝精简几面 + 计数；中尺寸(长条)＝铺满去过国家国旗 + 一句话。
/// （作为 `LumiWidget` 的「国旗」模式，及独立 `FlagWidget` 共用。）
struct FlagWidgetView: View {
    let snapshot: LumiSnapshot
    @Environment(\.widgetFamily) private var family

    private var allFlags: [String] { snapshot.litCountryCodes.map(flagEmoji) }

    var body: some View {
        if !WidgetTheme.plusActive {
            WidgetPlusLock()
        } else if allFlags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(section: "去过的国旗")
                Spacer()
                Text("还没有点亮国家").font(.system(size: 12)).foregroundStyle(WidgetTheme.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(WidgetChrome.pad)
        } else if family == .systemSmall {
            small
        } else {
            medium
        }
    }

    // 小尺寸：最多 8 面国旗（2 排）+ 计数
    private let smallMax = 8
    private let smallPerRow = 4
    private var smallRows: [[String]] {
        let s = Array(allFlags.prefix(smallMax))
        return stride(from: 0, to: s.count, by: smallPerRow).map { Array(s[$0..<min($0 + smallPerRow, s.count)]) }
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(section: "去过的国旗")
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(smallRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, f in
                            Text(f).font(.system(size: 24))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text(snapshot.countries > smallMax ? "已点亮 \(snapshot.countries) 国 · +\(snapshot.countries - smallMax)" : "已点亮 \(snapshot.countries) 国")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(WidgetTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(WidgetChrome.pad)
    }

    // 中尺寸(长条)：尽量铺满去过国家国旗 + 计数 + 一句话
    private let perRow = 13
    private let maxShown = 52
    private var shown: [String] { Array(allFlags.prefix(maxShown)) }
    private var rows: [[String]] {
        stride(from: 0, to: shown.count, by: perRow).map { Array(shown[$0..<min($0 + perRow, shown.count)]) }
    }
    private var overflow: Int { max(0, snapshot.countries - shown.count) }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                WidgetHeader(section: "去过的国旗")
                Spacer()
                Text("已点亮 \(snapshot.countries) 国 · \(snapshot.cities) 城")
                    .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(WidgetTheme.muted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 1.5) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, f in
                            Text(f).font(.system(size: 16))
                        }
                    }
                }
                if overflow > 0 {
                    Text("+\(overflow) 更多").font(.system(size: 10, weight: .bold)).foregroundStyle(WidgetTheme.lit)
                }
            }
            Spacer(minLength: 0)
            Text("世界正被你逐一点亮 ✦")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(WidgetTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetChrome.pad)
    }
}
