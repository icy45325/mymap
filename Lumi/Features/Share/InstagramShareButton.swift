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
                if let ui = render() { InstagramShare.shareToFeed(ui) }
            } label: {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 52)       // 与同排「分享」按钮等高
                    .background(
                        // IG 渐变意象（紫→粉→橙），与应用霓虹同源
                        LinearGradient(colors: [Color(hex: 0x7A3FF0), Color(hex: 0xFF3D9A), Color(hex: 0xFF9A45)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("分享到 Instagram"))
        }
    }
}
