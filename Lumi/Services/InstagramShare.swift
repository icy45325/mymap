import UIKit

/// 分享到 Instagram —— 默认以 **Feed 帖子**形式（单图发帖编辑器），原分辨率、不裁切。
///
/// 走多年通用的 `com.instagram.exclusivegram` 文档分享：把图写成 `.igo` 临时文件，
/// 用 `UIDocumentInteractionController` 以该 UTI「Open in…」→ 仅 Instagram → 进发帖编辑器。
/// 无需 SDK / 后端 / 相册权限。需在 Info.plist `LSApplicationQueriesSchemes` 声明 `instagram`。
/// 未装 IG → `isAvailable` 为 false，调用方应回退到系统分享面板。
@MainActor
enum InstagramShare {
    private static let appURL = URL(string: "instagram://app")!
    private static var docController: UIDocumentInteractionController?   // 展示期间强引用保活

    /// 本机是否装了 Instagram。
    static var isAvailable: Bool {
        UIApplication.shared.canOpenURL(appURL)
    }

    /// 以 Feed 帖子形式分享一张图。返回是否成功发起。
    @discardableResult
    static func shareToFeed(_ image: UIImage) -> Bool {
        guard isAvailable,
              let data = image.jpegData(compressionQuality: 1),
              let view = keyRootView else { return false }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumi-ig.igo")
        do { try data.write(to: url, options: .atomic) } catch { return false }

        let doc = UIDocumentInteractionController(url: url)
        doc.uti = "com.instagram.exclusivegram"   // 独占 UTI → 候选项只有 Instagram → 进发帖
        docController = doc
        let anchor = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        return doc.presentOpenInMenu(from: anchor, in: view, animated: true)
    }

    /// 当前 key window 的根视图（文档分享需要一个呈现锚点）。
    private static var keyRootView: UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?.view
    }
}
