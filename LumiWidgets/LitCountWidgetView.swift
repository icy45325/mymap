import SwiftUI
import WidgetKit

/// 「点亮战绩」小组件视图：按尺寸族分别布局。
/// systemMedium 复刻产品示意图（左星图 + 右计数）；其余尺寸做对应裁剪。
struct LitCountWidgetView: View {

    let snapshot: LumiSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:        small
        case .systemMedium:       medium
        case .accessoryRectangular: rectangular
        case .accessoryInline:    inline
        default:                  medium
        }
    }

    // MARK: - 主屏中尺寸（示意图同款）

    private var medium: some View {
        HStack(spacing: 0) {
            DotField(litCodes: snapshot.litCountryCodes)
                .frame(maxWidth: .infinity)
                .padding(14)
            statsColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
        }
    }

    private var statsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LUMI · 点亮战绩")
                .font(.system(size: 10, weight: .semibold)).tracking(2)
                .foregroundStyle(WidgetTheme.muted)
            Text("\(snapshot.countries)")
                .font(WidgetTheme.serif(48))
                .foregroundStyle(WidgetTheme.orange)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("个国家被你点亮 · 全球 \(snapshot.worldPercent)%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let sub = lastLine {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.muted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - 主屏小尺寸（计数为主）

    private var small: some View {
        ZStack {
            DotField(litCodes: snapshot.litCountryCodes, baseDot: 2.5, litDot: 6)
                .opacity(0.5)
                .padding(8)
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text("\(snapshot.countries)")
                    .font(WidgetTheme.serif(44))
                    .foregroundStyle(WidgetTheme.orange)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text("国 · 全球 \(snapshot.worldPercent)%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    // MARK: - 锁屏：矩形 / 行内

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("✦ 已点亮 \(snapshot.countries) 国")
                .font(.system(size: 15, weight: .semibold))
            Text("全球 \(snapshot.worldPercent)% · \(snapshot.cities) 城")
                .font(.system(size: 12))
            if let sub = lastLine {
                Text(sub).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text("✦ 点亮 \(snapshot.countries) 国 · 全球 \(snapshot.worldPercent)%")
    }

    // MARK: - 文案

    /// 「上次你在 迪拜 ✦」——无数据时不显示。
    private var lastLine: String? {
        guard let place = snapshot.lastCountryName ?? snapshot.lastPlaceName else { return nil }
        return "上次你在 \(place) ✦"
    }
}
