import SwiftUI

/// 明信片接收枢纽：剪贴板 / 扫码 / lumi:// 链接 / AirDrop 四条入口都汇到这里，
/// 统一按 token 幂等去重后，置 `pending` 让 `RootTabView` 弹确认。
@MainActor
final class PostcardInbox: ObservableObject {
    static let shared = PostcardInbox()
    private init() {}

    @Published var pending: PostcardPayload?

    private let seenKey = "lumi.receivedTokens"

    func handle(url: URL) {
        if let p = PostcardToken.payload(from: url) { offer(p) }
    }
    func handle(text: String) {
        if let p = PostcardToken.find(in: text) { offer(p) }
    }

    private func offer(_ p: PostcardPayload) {
        let seen = Set((UserDefaults.standard.string(forKey: seenKey) ?? "")
            .split(separator: ",").map(String.init))
        guard !seen.contains(p.token) else { return }
        pending = p
    }
}
