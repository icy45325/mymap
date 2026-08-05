import UIKit

/// 分享到 Instagram —— **直接拉起 Instagram 快拍**（不是系统通用分享面板）。
///
/// 走官方 `instagram-stories://share` + 剪贴板 `com.instagram.sharedSticker.*` 约定：
/// 用 **stickerImage**（整图作为贴纸、不裁切 → 清晰）叠在渐变背景上，直接进 IG 快拍编辑器。
/// 需 Info.plist `LSApplicationQueriesSchemes` 含 `instagram` / `instagram-stories`。
/// 未装 IG → `isAvailable` false，按钮不显示。
@MainActor
enum InstagramShare {
    private static let appURL = URL(string: "instagram://app")!
    private static let storiesURL =
        URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "")")!

    /// 本机是否装了 Instagram。
    static var isAvailable: Bool { UIApplication.shared.canOpenURL(storiesURL) }

    /// 把图作为快拍贴纸直接拉起 Instagram（整图不裁切 + 应用主题渐变底）。
    static func share(_ image: UIImage) {
        guard isAvailable, let data = image.pngData() else { return }
        let items: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": data,          // 整图贴纸，不裁切
            "com.instagram.sharedSticker.backgroundTopColor": "#140A22",
            "com.instagram.sharedSticker.backgroundBottomColor": "#06060E",
        ]
        UIPasteboard.general.setItems([items],
                                      options: [.expirationDate: Date().addingTimeInterval(60 * 5)])
        UIApplication.shared.open(storiesURL)
    }
}
