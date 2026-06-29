import SwiftUI

/// 「分享到 Instagram」按钮——**紧凑 logo 版**，与主「分享」按钮同排并列。
/// 仅在装了 IG 时出现（不装则不渲染 → 主分享按钮占满整行）。
/// `render` 在点按时按高倍率现出图（保证清晰），避免常驻持有大位图。
struct InstagramShareButton: View {
    /// 点按时产出要分享的高清位图（nil 则忽略）。
    let render: () -> UIImage?

    var body: some View {
        if InstagramShare.isAvailable {
            Button {
                if let ui = render() { InstagramShare.share(ui) }
            } label: {
                InstagramGlyph()
                    .stroke(.white, lineWidth: 2.2)
                    .frame(width: 26, height: 26)
                    .frame(width: 58, height: 52)
                    .background(
                        // Instagram 官方渐变（紫蓝→粉→橙黄）
                        LinearGradient(colors: [Color(hex: 0x515BD4), Color(hex: 0x8134AF),
                                                Color(hex: 0xDD2A7B), Color(hex: 0xF58529), Color(hex: 0xFEDA77)],
                                       startPoint: .bottomLeading, endPoint: .topTrailing),
                        in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("分享到 Instagram"))
        }
    }
}

/// Instagram 相机标志（圆角方框 + 中心圆 + 右上角小点）——线条版，描边渲染。
private struct InstagramGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // 外框圆角方
        let corner = w * 0.28
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: corner, height: corner))
        // 中心镜头圆
        let lens = w * 0.46
        p.addEllipse(in: CGRect(x: rect.midX - lens / 2, y: rect.midY - lens / 2, width: lens, height: lens))
        // 右上角小点
        let dot = w * 0.11
        p.addEllipse(in: CGRect(x: rect.maxX - w * 0.26, y: rect.minY + h * 0.15, width: dot, height: dot))
        return p
    }
}
