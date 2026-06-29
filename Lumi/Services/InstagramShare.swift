import UIKit

/// 分享到 Instagram —— 默认以 **Feed 帖子**形式（单图发帖编辑器），原分辨率、不裁切。
///
/// 走多年通用的 `com.instagram.exclusivegram` 文档分享：把图写成 `.igo` 临时文件，
/// 用 `UIDocumentInteractionController` 以该 UTI「Open in…」→ 仅 Instagram → 进发帖编辑器。
/// 关键：必须从**当前最顶层已呈现的 VC**弹出（分享按钮在 sheet 里，根 VC 在 sheet 之下会弹不出来）。
/// 若文档分享起不来（IG 版本变动等），**回退到系统分享面板**保证一定有弹窗。
@MainActor
enum InstagramShare {
    private static let appURL = URL(string: "instagram://app")!
    private static var docController: UIDocumentInteractionController?   // 展示期间强引用保活
    private static var docDelegate: DocDelegate?

    /// 本机是否装了 Instagram。
    static var isAvailable: Bool {
        UIApplication.shared.canOpenURL(appURL)
    }

    /// 以 Feed 帖子形式分享一张图。失败则回退系统分享面板。
    static func shareToFeed(_ image: UIImage) {
        guard let top = topViewController() else { return }
        if let data = image.jpegData(compressionQuality: 1) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumi-ig.igo")
            if (try? data.write(to: url, options: .atomic)) != nil {
                let doc = UIDocumentInteractionController(url: url)
                doc.uti = "com.instagram.exclusivegram"   // 独占 UTI → 候选项只有 Instagram → 进发帖
                let delegate = DocDelegate()
                docDelegate = delegate
                doc.delegate = delegate
                docController = doc
                let anchor = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 8, width: 0, height: 0)
                if doc.presentOpenInMenu(from: anchor, in: top.view, animated: true) { return }
            }
        }
        // 兜底：系统分享面板（一定会弹）
        presentSystemShare(image, from: top)
    }

    private static func presentSystemShare(_ image: UIImage, from top: UIViewController) {
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let pop = av.popoverPresentationController {          // iPad 需要锚点
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 8, width: 0, height: 0)
        }
        top.present(av, animated: true)
    }

    /// 当前最顶层已呈现的 VC（穿过 sheet / 导航 / Tab）。
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private final class DocDelegate: NSObject, UIDocumentInteractionControllerDelegate {
        func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
            InstagramShare.docController = nil
            InstagramShare.docDelegate = nil
        }
    }
}
