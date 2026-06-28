import SwiftUI
import CoreLocation

/// 世界地图（等距圆柱投影）：画全部国家轮廓，已点亮的着色。Canvas 静态绘制，可入 ImageRenderer。
struct WorldHighlightMap: View {
    let lit: Set<String>
    var litColor: Color = Color(hex: 0x39D98A)
    var baseColor: Color = Color.white.opacity(0.12)

    /// 底图轮廓只展开一次。
    private static let rings: [LitRegion] = Boundaries.shared.allCountryRings

    var body: some View {
        Canvas { ctx, size in
            func project(_ c: CLLocationCoordinate2D) -> CGPoint {
                CGPoint(x: (c.longitude + 180) / 360 * size.width,
                        y: (90 - c.latitude) / 180 * size.height)
            }
            func path(_ region: LitRegion) -> Path {
                var p = Path()
                for ring in region.rings {
                    var started = false
                    var prevLon = 0.0
                    for c in ring {
                        let pt = project(c)
                        if !started {
                            p.move(to: pt); started = true
                        } else if abs(c.longitude - prevLon) > 180 {
                            p.move(to: pt)        // 跨 ±180° 反经线：断开，避免横贯条纹
                        } else {
                            p.addLine(to: pt)
                        }
                        prevLon = c.longitude
                    }
                    if started { p.closeSubpath() }
                }
                return p
            }
            for region in Self.rings where !lit.contains(region.id) {
                ctx.fill(path(region), with: .color(baseColor))
            }
            for region in Self.rings where lit.contains(region.id) {
                ctx.fill(path(region), with: .color(litColor))
            }
        }
        .aspectRatio(2, contentMode: .fit)   // 等距圆柱 2:1
    }
}

/// 成就数据报告卡：整体统计渲染成可分享图（去过 N 国 + 世界地图 + UN/大洲/城市）。
/// 供 `ShareRender.image(_:)` 渲染；固定 360 宽。
struct StatsReportCard: View {
    let stats: LumiStats

    private var lit: Set<String> { stats.litCountryCodes }
    private var percentText: String { String(format: "%.0f%%", stats.worldPercent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LUMI").font(.system(size: 14, weight: .heavy)).tracking(3)
                    .foregroundStyle(LinearGradient.neonH)
                Spacer()
                Text("我的旅行护照").font(.system(size: 10, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(Color.nPurple).textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.countries)").font(Typo.serif(60))
                    .foregroundStyle(LinearGradient.neonH)
                Text("个国家已点亮").font(.system(size: 15)).foregroundStyle(Color(hex: 0xCBBEE6))
            }

            WorldHighlightMap(lit: lit, litColor: .nPink, baseColor: Color.nPurple.opacity(0.16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            // 进度条
            VStack(spacing: 6) {
                HStack {
                    Text("\(stats.countries) / \(stats.worldTotal)")
                        .font(.system(size: 11)).foregroundStyle(Color(hex: 0xCBBEE6).opacity(0.7))
                    Spacer()
                    Text(percentText).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.nPink)
                }
                NeonBar(fraction: min(1, stats.worldPercent / 100), height: 6)
            }

            HStack(spacing: 10) {
                reportStat("\(stats.countries) / \(Boundaries.shared.unMemberCount)", "UN 成员国")
                reportStat("\(stats.continentsCovered) / 7", "大洲")
                reportStat("\(stats.cities)", "城市")
            }

            Text("点亮你的旅行足迹 · Lumi")
                .font(.system(size: 10, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.nPink.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(22)
        .frame(width: 360)
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: 0x140A22), Color(hex: 0x06060E)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color.nPurple.opacity(0.35), .clear],
                               center: .topLeading, startRadius: 8, endRadius: 320)
            }
        )
    }

    private func reportStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(Typo.serif(19)).foregroundStyle(Color.text)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.localized).font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.nPurple).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11).padding(.horizontal, 11)
        .background(Color.nPurple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nPurple.opacity(0.35), lineWidth: 1))
    }
}
