import SwiftUI
import CoreLocation

// ─────────────────────────────────────────────────────────────
//  点阵光点世界地图（可选沉浸模式）。
//
//  用等距圆柱投影把足迹 lat/lon 映射成发光光点；陆地以暗点阵示意，
//  分布来自 DotMatrixLand 真实国界位图（admin0 → 128×64，与官网首屏地图同源）。
//  真实地理判定仍在主页 MapKit + 离线 point-in-polygon，二者解耦。
// ─────────────────────────────────────────────────────────────

/// 点阵光点地图背景（首页默认底图，展示用、不接收点击）。
/// 霓虹氛围光 + 点阵陆地 + 足迹脉冲光点，铺满容器；地理录入靠 FAB / 放大后的真实地图。
struct DotMatrixBackground: View {
    let footprints: [Footprint]

    @State private var pulse = false
    /// 主题地图色板（主题切换时根视图整树重建，无需自行观察）。
    private var skin: AppTheme.Palette { AppTheme.applied.palette }

    var body: some View {
        GeometryReader { geo in
            let mapW = geo.size.width * 1.25
            let mapH = mapW * 188.0 / 360.0
            ZStack {
                RadialGradient(colors: [skin.glow.opacity(0.30), skin.glow.opacity(0.06), .clear],
                               center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 460)
                ZStack {
                    DotMatrixWorld(footprints: footprints, skin: skin)
                    PinsLayer(footprints: footprints, pulse: pulse, skin: skin)
                }
                .frame(width: mapW, height: mapH)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: - 投影

/// 等距圆柱投影：WGS-84 → 归一化 0...1（x 经度、y 纬度）。
enum MapProjection {
    static func normalized(_ c: CLLocationCoordinate2D) -> CGPoint {
        CGPoint(x: (c.longitude + 180) / 360, y: (90 - c.latitude) / 180)
    }
    static func point(_ c: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let n = normalized(c)
        return CGPoint(x: n.x * size.width, y: n.y * size.height)
    }
}

// MARK: - 点阵陆地（Canvas）

/// 暗点阵陆地 + 城市附近高亮，靠 Canvas 一次绘制。
/// 陆地分布来自 DotMatrixLand（admin0 真实国界 → 128×64 位图，与官网首屏同源），
/// 网格中心经 MapProjection 投影落点——与 PinsLayer 同一投影，足迹光点必然落在对应大洲。
private struct DotMatrixWorld: View {
    let footprints: [Footprint]
    let skin: AppTheme.Palette

    private var cityPoints: [CGPoint] {
        footprints.map { MapProjection.normalized($0.coordinate) }
    }

    var body: some View {
        let cities = cityPoints
        Canvas { ctx, size in
            for gy in 0..<DotMatrixLand.gridH {
                for gx in 0..<DotMatrixLand.gridW {
                    guard DotMatrixLand.land(gx: gx, gy: gy) else { continue }
                    let c = DotMatrixLand.coordinate(gx: gx, gy: gy)
                    let n = MapProjection.normalized(CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon))
                    let d = Self.nearestCity(n.x, n.y, cities)
                    let (color, r) = Self.style(forDistance: d, skin: skin)
                    let i = gy &* DotMatrixLand.gridW &+ gx
                    let jx = n.x * size.width + Self.jitter(i)
                    let jy = n.y * size.height + Self.jitter(i &+ 7)
                    ctx.fill(Path(ellipseIn: CGRect(x: jx - r, y: jy - r, width: r * 2, height: r * 2)),
                             with: .color(color))
                }
            }
        }
    }

    private static func nearestCity(_ nx: Double, _ ny: Double, _ cities: [CGPoint]) -> Double {
        var m = 9.0
        for c in cities {
            let d = hypot(nx - c.x, ny - c.y)
            if d < m { m = d }
        }
        return m
    }

    private static func style(forDistance d: Double, skin: AppTheme.Palette) -> (Color, CGFloat) {
        if d < 0.045 { return (skin.dotNear, 1.7) }   // 紧邻足迹
        if d < 0.085 { return (skin.dotMid, 1.45) }   // 近
        if d < 0.16  { return (skin.dotFar, 1.2) }    // 中距过渡（更宽，过渡更顺）
        return (skin.dotBase, 1.15)                   // 基线：未去过的大陆也读成完整点阵地球
    }

    /// 确定性抖动（避免每帧重绘抖动闪烁）：返回约 -0.7...0.7。
    private static func jitter(_ i: Int) -> CGFloat {
        let v = sin(Double(i) * 12.9898) * 43758.5453
        return CGFloat((v - v.rounded(.down)) - 0.5) * 1.4
    }
}

// MARK: - 足迹光点层

private struct PinsLayer: View {
    let footprints: [Footprint]
    let pulse: Bool
    let skin: AppTheme.Palette

    var body: some View {
        GeometryReader { geo in
            ForEach(footprints) { fp in
                let p = MapProjection.point(fp.coordinate, in: geo.size)
                // 脉冲环
                Circle().stroke(skin.pinTop, lineWidth: 1.3)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 3.4 : 1)
                    .opacity(pulse ? 0 : 0.9)
                    .position(p)
                // 发光点 + 白芯
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [skin.pinTop, skin.pinBottom], startPoint: .top, endPoint: .bottom))
                        .frame(width: 8, height: 8)
                        .shadow(color: skin.pinTop.opacity(0.9), radius: 5)
                    Circle().fill(.white).frame(width: 3, height: 3)
                }
                .position(p)
                // 标签
                Text(fp.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xEDEDF5))
                    .fixedSize()
                    .position(p)
                    .offset(x: 30, y: 1)
            }
        }
    }
}
