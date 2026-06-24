import SwiftUI
import CoreLocation

// ─────────────────────────────────────────────────────────────
//  点阵光点世界地图（可选沉浸模式）。
//
//  程序生成、非真实地理边界：用等距圆柱投影把足迹 lat/lon 映射成发光光点，
//  陆地以暗点阵示意（对齐原型 lumi_style1_v2_dotmatrix.html 的沉浸地图）。
//  真实地理判定仍在主页 MapKit + 离线 point-in-polygon，二者解耦。
// ─────────────────────────────────────────────────────────────

/// 点阵光点地图背景（首页默认底图，展示用、不接收点击）。
/// 霓虹氛围光 + 点阵陆地 + 足迹脉冲光点，铺满容器；地理录入靠 FAB / 放大后的真实地图。
struct DotMatrixBackground: View {
    let footprints: [Footprint]

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let mapW = geo.size.width * 1.25
            let mapH = mapW * 188.0 / 360.0
            ZStack {
                RadialGradient(colors: [Color.nPurple.opacity(0.30), .clear],
                               center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 360)
                ZStack {
                    DotMatrixWorld(footprints: footprints)
                    PinsLayer(footprints: footprints, pulse: pulse)
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

/// 放大后的真实 MapKit 地图全屏页（不含精彩瞬间；保留点屏落点）。
struct RealMapScreen: View {
    let mapView: AnyView
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.bg.ignoresSafeArea()
            mapView.ignoresSafeArea()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.42), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .padding(.trailing, 22).padding(.top, 54)
        }
        .preferredColorScheme(.dark)
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
private struct DotMatrixWorld: View {
    let footprints: [Footprint]

    /// 陆地近似椭圆 [cx, cy, rx, ry]（归一化），源自原型 land 数组。
    private static let land: [[Double]] = [
        [0.17,0.27,0.10,0.11],[0.22,0.37,0.06,0.07],[0.13,0.19,0.06,0.05],[0.24,0.30,0.05,0.06],
        [0.24,0.45,0.03,0.04],[0.30,0.60,0.05,0.08],[0.32,0.72,0.03,0.06],[0.31,0.15,0.035,0.045],
        [0.49,0.25,0.05,0.045],[0.45,0.22,0.03,0.03],[0.52,0.40,0.05,0.07],[0.53,0.52,0.055,0.10],
        [0.585,0.34,0.045,0.05],[0.70,0.27,0.13,0.10],[0.78,0.22,0.07,0.06],[0.655,0.43,0.035,0.045],
        [0.755,0.45,0.04,0.035],[0.84,0.64,0.06,0.045],
    ]

    private var cityPoints: [CGPoint] {
        footprints.map { MapProjection.normalized($0.coordinate) }
    }

    var body: some View {
        let cities = cityPoints
        Canvas { ctx, size in
            let step = max(3.5, size.width / 96)
            var i = 0
            var py = step
            while py < size.height - step {
                var px = step
                while px < size.width - step {
                    let nx = px / size.width, ny = py / size.height
                    if Self.inLand(nx, ny) {
                        let d = Self.nearestCity(nx, ny, cities)
                        let (color, r) = Self.style(forDistance: d)
                        let jx = px + Self.jitter(i), jy = py + Self.jitter(i &+ 7)
                        ctx.fill(Path(ellipseIn: CGRect(x: jx - r, y: jy - r, width: r * 2, height: r * 2)),
                                 with: .color(color))
                    }
                    i &+= 1
                    px += step
                }
                py += step
            }
        }
    }

    private static func inLand(_ nx: Double, _ ny: Double) -> Bool {
        for e in land {
            let dx = (nx - e[0]) / e[2], dy = (ny - e[1]) / e[3]
            if dx * dx + dy * dy <= 1 { return true }
        }
        return false
    }

    private static func nearestCity(_ nx: Double, _ ny: Double, _ cities: [CGPoint]) -> Double {
        var m = 9.0
        for c in cities {
            let d = hypot(nx - c.x, ny - c.y)
            if d < m { m = d }
        }
        return m
    }

    private static func style(forDistance d: Double) -> (Color, CGFloat) {
        if d < 0.045 { return (Color(hex: 0xE59BF0), 1.6) }
        if d < 0.085 { return (Color(hex: 0x9B6FD0), 1.35) }
        if d < 0.13  { return (Color(hex: 0x5B4A82), 1.1) }
        return (Color(hex: 0x2A2A3C), 1.05)
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

    var body: some View {
        GeometryReader { geo in
            ForEach(footprints) { fp in
                let p = MapProjection.point(fp.coordinate, in: geo.size)
                // 脉冲环
                Circle().stroke(Color.nPink, lineWidth: 1.3)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 3.4 : 1)
                    .opacity(pulse ? 0 : 0.9)
                    .position(p)
                // 发光点 + 白芯
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.nPink, .nOrange], startPoint: .top, endPoint: .bottom))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.nPink.opacity(0.9), radius: 5)
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
