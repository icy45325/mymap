import SwiftUI
import WidgetKit

/// 「去年今日」视图：按尺寸族分别布局；无匹配回忆时给鼓励性空态。
struct OnThisDayWidgetView: View {

    let entry: OnThisDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:          small
        case .systemMedium:         medium
        case .accessoryRectangular: rectangular
        case .accessoryInline:      inline
        default:                    medium
        }
    }

    // MARK: - 主屏中尺寸

    private var medium: some View {
        ZStack {
            DotMatrixBackdrop(litCodes: entry.litCountryCodes)
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(section: "去年今日")
                if let m = entry.memory {
                    HStack(spacing: 8) {
                        Text(WidgetTheme.flag(for: m.countryCode)).font(.system(size: 26))
                        Text(m.placeName)
                            .font(WidgetTheme.serif(28))
                            .foregroundStyle(WidgetTheme.text)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Text(recallLine(m))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetTheme.lit)
                    if let mood = m.mood {
                        Text("「\(mood)」")
                            .font(.system(size: 12))
                            .foregroundStyle(WidgetTheme.muted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetChrome.pad)
        }
    }

    // MARK: - 主屏小尺寸

    private var small: some View {
        ZStack {
            DotMatrixBackdrop(litCodes: entry.litCountryCodes)   // 满幅肌理
            VStack(alignment: .leading, spacing: 4) {
                WidgetHeader(section: "去年今日")
                Spacer(minLength: 0)
                if let m = entry.memory {
                    Text(WidgetTheme.flag(for: m.countryCode)).font(.system(size: 24))
                    Text(m.placeName)
                        .font(WidgetTheme.serif(22))
                        .foregroundStyle(WidgetTheme.text)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(recallLine(m))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(WidgetTheme.lit)
                        .lineLimit(1)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetChrome.pad)
        }
    }

    // MARK: - 锁屏

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let m = entry.memory {
                Text("✦ \(yearsAgoPhrase(m))")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(WidgetTheme.flag(for: m.countryCode)) \(m.placeName)")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                if let mood = m.mood {
                    Text(mood).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("✦ 去年今日").font(.system(size: 13, weight: .semibold))
                Text("还没有足迹，去点亮一个").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var inline: some View {
        if let m = entry.memory {
            Text("✦ \(yearsAgoPhrase(m))你在 \(m.placeName)")
        } else {
            Text("✦ 去年今日 · 去点亮一个足迹")
        }
    }

    // MARK: - 公共件

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("这一天还没有回忆")
                .font(WidgetTheme.serif(20)).foregroundStyle(WidgetTheme.text)
            Text("去点亮一个足迹，明年今日就有得回看了 ✦")
                .font(.system(size: 11)).foregroundStyle(WidgetTheme.muted)
                .lineLimit(2)
        }
    }

    // MARK: - 文案

    /// 整段回忆句：「去年此刻，你在 阿拉伯联合酋长国 ✦」/「N 年前的今天，你在 … ✦」。
    private func recallLine(_ m: LumiMemory) -> String {
        let place = m.countryName ?? m.placeName
        let years = yearsBetween(m)
        if years <= 1 { return String(localized: "去年此刻，你在 \(place) ✦") }
        return String(localized: "\(years) 年前的今天，你在 \(place) ✦")
    }

    /// 锁屏紧凑短语：「去年今日」/「N 年前今日」。
    private func yearsAgoPhrase(_ m: LumiMemory) -> String {
        let years = yearsBetween(m)
        if years <= 1 { return String(localized: "去年今日") }
        return String(localized: "\(years) 年前今日")
    }

    private func yearsBetween(_ m: LumiMemory) -> Int {
        let comps = Calendar.current.dateComponents([.year], from: m.visitedAt, to: entry.date)
        return max(comps.year ?? 1, 1)
    }
}
