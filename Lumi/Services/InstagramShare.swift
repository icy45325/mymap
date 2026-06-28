import UIKit

/// 分享到 Instagram 快拍（Stories）——把一张图作为快拍背景直接拉起 IG。
///
/// 走官方 `instagram-stories://share` + 剪贴板 `com.instagram.sharedSticker.*` 约定，无需 SDK / 后端。
/// 需在 Info.plist `LSApplicationQueriesSchemes` 声明 `instagram-stories`，否则 `isAvailable` 恒 false。
/// 未装 IG → `isAvailable` 为 false，调用方应回退到系统分享面板。
@MainActor
enum InstagramShare {
    private static let storiesURL = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "")")!

    /// 本机是否装了 Instagram 且可分享快拍。
    static var isAvailable: Bool {
        UIApplication.shared.canOpenURL(storiesURL)
    }

    /// 把 `image` 作为快拍背景拉起 Instagram。返回是否成功发起。
    @discardableResult
    static func shareToStories(_ image: UIImage) -> Bool {
        guard isAvailable, let data = image.pngData() else { return false }
        // 背景图 + 上下渐变兜底色（IG 在背景图比例不满屏时用）。
        let items: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": data,
            "com.instagram.sharedSticker.backgroundTopColor": "#06060E",
            "com.instagram.sharedSticker.backgroundBottomColor": "#140A22",
        ]
        UIPasteboard.general.setItems([items],
                                      options: [.expirationDate: Date().addingTimeInterval(60 * 5)])
        UIApplication.shared.open(storiesURL)
        return true
    }
}
