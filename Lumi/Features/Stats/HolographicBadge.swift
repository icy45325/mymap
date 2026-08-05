import SwiftUI

/// 全息徽章大图：在 `HexBadge` 上叠彩虹箔流光 + 扫光带，随设备倾斜偏移（CoreMotion）；
/// 无 motion 时由 `TimelineView` 自动缓慢扫光兜底。纯 SwiftUI（后续可换 Metal shader 提质）。
struct HolographicBadge: View {
    let badge: Badge
    var size: CGFloat = 150

    @StateObject private var motion = MotionTilt()

    var body: some View {
        SwiftUI.TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let shift = motion.roll * 0.6 + sin(t * 0.5) * 0.18      // 流光相位
            ZStack {
                HexBadge(badge: badge, size: size)
                if badge.state == .lit {
                    foil(t: t, shift: shift)
                        .frame(width: size, height: size * 1.15)
                        .mask(foilMask)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: size, height: size * 1.15)
            .rotation3DEffect(.degrees(motion.roll * 10), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(-motion.pitch * 8), axis: (x: 1, y: 0, z: 0))
            .shadow(color: badge.color.opacity(0.6), radius: 22)
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    /// 流光遮罩：插画徽章按图形轮廓，否则六边形。
    @ViewBuilder private var foilMask: some View {
        if let img = badge.resolvedImageName {
            Image(img).resizable().scaledToFit().frame(width: size, height: size * 1.15)
        } else {
            Hexagon().padding(2).frame(width: size, height: size * 1.15)
        }
    }

    private func foil(t: Double, shift: Double) -> some View {
        ZStack {
            AngularGradient(
                gradient: Gradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]),
                center: .center,
                angle: .degrees(t * 26 + shift * 200))
                .opacity(0.5)
            // 斜向扫光高光带，随倾斜移动
            LinearGradient(colors: [.clear, .white.opacity(0.7), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .rotationEffect(.degrees(35))
                .offset(x: CGFloat(shift) * size * 0.9)
                .blendMode(.screen)
        }
    }
}

/// 解锁粒子迸发：从中心向四周发光粒子，自动消散。Canvas + TimelineView，轻量无依赖。
struct UnlockBurst: View {
    var color: Color
    var count: Int = 90

    private struct P { let angle: Double; let speed: Double; let size: Double; let delay: Double }
    @State private var start = Date()
    private let particles: [P]

    init(color: Color, count: Int = 90) {
        self.color = color
        self.count = count
        // 用确定性伪随机（基于索引）布点，避免依赖 Date/Random 之外的来源
        particles = (0..<count).map { i in
            let a = Double(i) / Double(count) * .pi * 2 + Double(i % 7) * 0.13
            return P(angle: a,
                     speed: 70 + Double((i * 53) % 160),
                     size: 2 + Double((i * 17) % 5),
                     delay: Double((i * 29) % 100) / 700)
        }
    }

    var body: some View {
        SwiftUI.TimelineView(.animation) { tl in
            let elapsed = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for p in particles {
                    let lt = max(0, elapsed - p.delay)
                    let life = min(1, lt / 1.1)
                    if life <= 0 || life >= 1 { continue }
                    let dist = p.speed * lt * (1 - life * 0.4)
                    let x = c.x + cos(p.angle) * dist
                    let y = c.y + sin(p.angle) * dist
                    let r = p.size * (1 - life)
                    let path = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    ctx.opacity = 1 - life
                    ctx.fill(path, with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
