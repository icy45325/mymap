import SwiftUI

// ─────────────────────────────────────────────────────────────
//  暗夜霓虹 v2 可复用组件。
// ─────────────────────────────────────────────────────────────

/// 渐变文字（标题里的高亮数字，原型 .big em）。
struct GradientText: View {
    let text: String
    var font: Font
    var body: some View {
        Text(text).font(font).foregroundStyle(LinearGradient.neonH)
    }
}

/// 尖顶六边形（原型 clip-path polygon 50%,0 100%,25% …）。
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        let pts = [(0.5, 0.0), (1.0, 0.25), (1.0, 0.75),
                   (0.5, 1.0), (0.0, 0.75), (0.0, 0.25)]
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: x + pt.0 * w, y: y + pt.1 * h)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// 蜂巢徽章六边形：rim 描边 + 底 + 进度填充 + 图标 + 进度百分比。
struct HexBadge: View {
    let badge: Badge
    var size: CGFloat = 60
    var dimmed: Bool = false

    private var h: CGFloat { size * 1.15 }

    var body: some View {
        ZStack {
            // rim
            Hexagon().fill(rimColor)
            // 底 / 满填充
            Hexagon().fill(bgStyle).padding(2)
            // 进行中：从底部按进度填充
            if badge.state == .prog, let p = badge.progress {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().fill(badge.rarity.fill)
                            .frame(height: geo.size.height * p)
                            .opacity(0.92)
                    }
                }
                .clipShape(Hexagon())
                .padding(2)
            }
            // 图标
            Image(systemName: badge.state == .locked ? "lock.fill" : badge.icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(iconColor)
            // 进度百分比
            if badge.state == .prog, let p = badge.progress {
                VStack {
                    Spacer()
                    Text("\(Int(p * 100))%")
                        .font(.system(size: size * 0.14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.bottom, size * 0.1)
                }
            }
        }
        .frame(width: size, height: h)
        .shadow(color: badge.state == .lit ? badge.rarity.color.opacity(0.55) : .black.opacity(0.4),
                radius: badge.state == .lit ? 9 : 4, y: 3)
        .opacity(dimmed ? 0.13 : 1)
        .animation(.easeInOut(duration: 0.25), value: dimmed)
    }

    private var rimColor: Color {
        switch badge.state {
        case .lit:    return badge.rarity.color.opacity(0.8)
        case .prog:   return badge.rarity.color.opacity(0.6)
        case .locked: return Color(hex: 0x242436)
        }
    }
    private var bgStyle: AnyShapeStyle {
        switch badge.state {
        case .lit:    return AnyShapeStyle(badge.rarity.fill)
        case .prog:   return AnyShapeStyle(Color(hex: 0x181826))
        case .locked: return AnyShapeStyle(Color(hex: 0x101019))
        }
    }
    private var iconColor: Color {
        badge.state == .locked ? .faint : .white
    }
}

/// 环形进度（原型 ring-c / cring，conic 渐变）。
struct RingProgress<Center: View>: View {
    var fraction: Double                 // 0...1
    var size: CGFloat
    var lineWidth: CGFloat = 7
    var colors: [Color] = [.nPink, .nPurple, .nCyan]
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(Color.panel2, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(AngularGradient(colors: colors, center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .frame(width: size, height: size)
    }
}

/// 霓虹进度条（原型 .track / .bar2）。
struct NeonBar: View {
    var fraction: Double
    var height: CGFloat = 8
    var glow: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.panel2)
                Capsule().fill(LinearGradient.neonH)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .shadow(color: glow ? Color.nPink.opacity(0.5) : .clear, radius: 8)
            }
        }
        .frame(height: height)
    }
}

/// 胶囊分段选择器（原型 .seg）。
struct SegmentBar<T: Hashable>: View {
    let items: [(value: T, label: String)]
    @Binding var selection: T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(items, id: \.value) { item in
                    let on = item.value == selection
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = item.value }
                    } label: {
                        Text(item.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? .white : Color.muted)
                            .padding(.vertical, 7).padding(.horizontal, 15)
                            .background {
                                if on { Capsule().fill(LinearGradient.neonH) }
                                else { Capsule().fill(Color.panel).overlay(Capsule().stroke(Color.line, lineWidth: 1)) }
                            }
                    }
                }
            }
            .padding(.horizontal, Metrics.pad)
        }
    }
}
