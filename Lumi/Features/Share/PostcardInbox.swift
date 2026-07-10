import SwiftUI

/// 明信片/交换日记接收枢纽：剪贴板 / 扫码 / lumi:// 链接 / AirDrop 四条入口都汇到这里，
/// 按口令前缀分流（`LUMI1:` 明信片 → `pending`；`LUMID1:` 交换日记 → `pendingDiary`），
/// 统一按 token 幂等去重后交 `RootTabView` 弹确认。
@MainActor
final class PostcardInbox: ObservableObject {
    static let shared = PostcardInbox()
    private init() {}

    @Published var pending: PostcardPayload?
    @Published var pendingDiary: DiaryPayload?

    /// 接收来源：剪贴板是**被动**探测（要躲开自己刚分享的卡，免得自弹）；
    /// 扫码 / lumi:// / AirDrop 是**主动**意图（即便是自己寄的也允许收下——「自己发自己收」）。
    enum Source { case clipboard, active }

    private let seenKey = "lumi.receivedTokens"     // 已收下/已忽略 → 真去重，所有来源都拦
    private let sharedKey = "lumi.sharedTokens"     // 本机分享出去的 → 仅剪贴板被动探测时跳过

    func handle(url: URL, source: Source = .active) {
        if let p = PostcardToken.payload(from: url) { offer(p, source: source); return }
        if let d = DiaryToken.payload(from: url) { offerDiary(d, source: source) }
    }
    func handle(text: String, source: Source = .active) {
        if let p = PostcardToken.find(in: text) { offer(p, source: source); return }
        if let d = DiaryToken.find(in: text) { offerDiary(d, source: source) }
    }

    /// 记录「我从本机分享出去的」口令——剪贴板被动探测会跳过它，避免发送方被自己刚分享的卡反复弹窗。
    func markShared(_ token: String) {
        var shared = tokens(sharedKey)
        shared.insert(token)
        UserDefaults.standard.set(shared.joined(separator: ","), forKey: sharedKey)
    }

    private func offer(_ p: PostcardPayload, source: Source) {
        guard allow(token: p.token, source: source) else { return }
        pending = p
    }

    private func offerDiary(_ d: DiaryPayload, source: Source) {
        guard allow(token: d.token, source: source) else { return }
        pendingDiary = d
    }

    /// 统一去重闸门：明信片与日记的 token 共用同一 seen/shared 集（token 全局唯一字符串）。
    private func allow(token: String, source: Source) -> Bool {
        guard !tokens(seenKey).contains(token) else { return false }             // 已收过，绝不重复
        if source == .clipboard, tokens(sharedKey).contains(token) { return false } // 自己刚分享的，剪贴板别弹
        return true
    }

    private func tokens(_ key: String) -> Set<String> {
        Set((UserDefaults.standard.string(forKey: key) ?? "").split(separator: ",").map(String.init))
    }
}
