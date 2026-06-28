import SwiftUI

/// 「分享到 Instagram」按钮——仅在装了 IG 时出现；点按把渲染好的图发到快拍。
/// `render` 惰性出图（点按时才渲染），避免常驻持有大位图。
struct InstagramStoryButton: View {
    /// 点按时产出要分享的位图（nil 则忽略）。
    let render: () -> UIImage?

    var body: some View {
        if InstagramShare.isAvailable {
            Button {
                if let ui = render() { InstagramShare.shareToStories(ui) }
            } label: {
                Label("分享到 Instagram", systemImage: "camera.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(
                        // IG 渐变意象（紫→粉→橙），与应用霓虹同源
                        LinearGradient(colors: [Color(hex: 0x7A3FF0), Color(hex: 0xFF3D9A), Color(hex: 0xFF9A45)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
