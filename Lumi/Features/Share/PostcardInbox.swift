import SwiftUI

/// 明信片接收枢纽：剪贴板 / 扫码 / lumi:// 链接 / AirDrop 四条入口都汇到这里，
/// 统一按 token 幂等去重后，置 `pending` 让 `RootTabView` 弹确认。
@MainActor
final class PostcardInbox: ObservableObject {
    static let shared = PostcardInbox()
    private init() {}

    @Published var pending: PostcardPayload?

    /// 接收来源：剪贴板是**被动**探测（要躲开自己刚分享的卡，免得自弹）；
    /// 扫码 / lumi:// / AirDrop 是**主动**意图（即便是自己寄的也允许收下——「自己发自己收」）。
    enum Source { case clipboard, active }

    private let seenKey = "lumi.receivedTokens"     // 已收下/已忽略 → 真去重，所有来源都拦
    private let sharedKey = "lumi.sharedTokens"     // 本机分享出去的 → 仅剪贴板被动探测时跳过

    func handle(url: URL, source: Source = .active) {
        if let p = PostcardToken.payload(from: url) { offer(p, source: source) }
    }
    func handle(text: String, source: Source = .active) {
        if let p = PostcardToken.find(in: text) { offer(p, source: source) }
    }

    /// 记录「我从本机分享出去的」口令——剪贴板被动探测会跳过它，避免发送方被自己刚分享的卡反复弹窗。
    func markShared(_ token: String) {
        var shared = tokens(sharedKey)
        shared.insert(token)
        UserDefaults.standard.set(shared.joined(separator: ","), forKey: sharedKey)
    }

    private func offer(_ p: PostcardPayload, source: Source) {
        guard !tokens(seenKey).contains(p.token) else { return }           // 已收过，绝不重复
        if source == .clipboard, tokens(sharedKey).contains(p.token) { return }  // 自己刚分享的，剪贴板别弹
        pending = p
    }

    private func tokens(_ key: String) -> Set<String> {
        Set((UserDefaults.standard.string(forKey: key) ?? "").split(separator: ",").map(String.init))
    }
}
