import SwiftUI
import SwiftData

/// 点亮成就（§4.4）：大数字 + 各洲进度 + 里程碑徽章。集邮满足感。
struct StatsView: View {

    @Query private var footprints: [Footprint]

    /// 大洲展示顺序与中文名。
    private static let continents: [(key: String, name: String)] = [
        ("Asia", "亚洲"), ("Europe", "欧洲"), ("Africa", "非洲"),
        ("North America", "北美洲"), ("South America", "南美洲"), ("Oceania", "大洋洲"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headline
                    badgesSection
                    continentsSection
                }
                .padding(Metrics.pad)
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.litGlow)
        .onAppear { Analytics.log(.statsViewed(totalLit: litCount, percent: percent)) }
    }

    // MARK: - 数据（与地图同源：distinct countryCode，§10④ 一致性）

    private var litCountryCodes: Set<String> { Set(footprints.compactMap { $0.countryCode }) }
    private var litCount: Int { litCountryCodes.count }
    private var cityCount: Int { Set(footprints.compactMap { $0.cityName }).count }

    private var percent: Int {
        let total = Boundaries.shared.totalCountryCount
        guard total > 0 else { return 0 }
        return Int((Double(litCount) / Double(total) * 100).rounded())
    }

    // MARK: - 大数字

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(litCount)")
                    .font(Typo.display(64))
                    .foregroundStyle(Color.litGlow)
                Text("个国家被你点亮")    // §11 #10
                    .font(.headline)
                    .foregroundStyle(Color.textSecondary)
            }
            Text("全球 \(percent)% · \(cityCount) 座城市")
                .font(Typo.mono(13))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 徽章

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("里程碑徽章")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeChip(badge: badge, unlocked: badge.isUnlocked(litCountryCodes))
                    }
                }
            }
        }
    }

    /// v0 示例徽章（§4.4「如…」）。
    private var badges: [Badge] {
        [
            Badge(id: "first", icon: "flag.fill", title: "第一步") { !$0.isEmpty },
            Badge(id: "desert", icon: "sun.max.fill", title: "沙漠之国") { $0.contains("AE") },
            Badge(id: "overseas", icon: "airplane", title: "首个海外国家") { $0.subtracting(["AE"]).count >= 1 },
            Badge(id: "five", icon: "globe.asia.australia.fill", title: "环游五国") { $0.count >= 5 },
            Badge(id: "ten", icon: "star.circle.fill", title: "环游十国") { $0.count >= 10 },
        ]
    }

    // MARK: - 各洲进度

    private var continentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("各大洲进度")
            ForEach(Self.continents, id: \.key) { continent in
                let total = Boundaries.shared.countriesPerContinent[continent.key] ?? 0
                let lit = litCountryCodes.filter {
                    Boundaries.shared.continent(forCountryCode: $0) == continent.key
                }.count
                ContinentBar(name: continent.name, lit: lit, total: total)
            }
        }
    }

    // MARK: - 小工具

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textSecondary)
    }
}

// MARK: - 徽章模型与视图

private struct Badge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let isUnlocked: (Set<String>) -> Bool
}

private struct BadgeChip: View {
    let badge: Badge
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.icon)
                .font(.system(size: 26))
                .foregroundStyle(unlocked ? Color.ink : Color.textMuted)
                .frame(width: 64, height: 64)
                .background(
                    Circle().fill(unlocked
                        ? AnyShapeStyle(LinearGradient(colors: [Color.litGlow, Color.litGlow2],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.panel))
                )
                .overlay(Circle().stroke(unlocked ? Color.litGlow : Color.line, lineWidth: 1))
            Text(badge.title)
                .font(.caption2)
                .foregroundStyle(unlocked ? Color.textPrimary : Color.textMuted)
        }
        .frame(width: 84)
        .opacity(unlocked ? 1 : 0.55)
    }
}

// MARK: - 大洲进度条

private struct ContinentBar: View {
    let name: String
    let lit: Int
    let total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(lit) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(lit) / \(total)").font(Typo.mono(12)).foregroundStyle(Color.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.panel)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.litGlow, Color.litGlow2],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * fraction) * (lit > 0 ? 1 : 0))
                }
            }
            .frame(height: 8)
        }
    }
}
