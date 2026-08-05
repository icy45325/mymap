import SwiftUI

/// 火漆封印：交换日记的签名视觉，接入 Lumi 既有邮政隐喻（邮票/邮戳/护照）。
/// `glow` = 可揭晓时的呼吸光圈（回访钩子，全屏最抢眼的元素）。
struct WaxSeal: View {
    var size: CGFloat = 34
    var glow: Bool = false

    @State private var pulse = false

    static let wax = Color(hex: 0xC0392B)
    static let wax2 = Color(hex: 0xE05445)

    var body: some View {
        ZStack {
            if glow {
                Circle()
                    .stroke(Color(hex: 0xFF6B4A).opacity(0.55), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.55 : 1)
                    .opacity(pulse ? 0 : 0.9)
            }
            Circle()
                .fill(RadialGradient(colors: [Self.wax2, Self.wax],
                                     center: UnitPoint(x: 0.34, y: 0.30),
                                     startRadius: 1, endRadius: size * 0.62))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color(hex: 0x7D2419), lineWidth: 1.2))
                .overlay(
                    Text(verbatim: "✦")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFF3EE))
                )
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        .onAppear {
            guard glow else { return }
            withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}
