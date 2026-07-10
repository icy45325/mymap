import Foundation
import SwiftData

/// 交换日记的配对 / 落壳 / 封存逻辑（纯本地状态机，无服务端）。
@MainActor
enum DiaryStore {

    // MARK: - 收件落壳

    enum AttachResult {
        case selfSent                    // 扫到 / 粘到自己封存的日记口令
        case attached(ExchangeDiary)     // pairID 命中既有日记本，密封壳已落
        case alreadyExchanged            // 该本已拆开交换过，忽略
        case needsChoice                 // 无命中：请用户选「收进已有本 / 新建一本」
    }

    /// 收到对方日记口令：按 diaryID / pairID 自动归位；两者都不命中交给 UI 选择。
    static func attach(_ payload: DiaryPayload, context: ModelContext) -> AttachResult {
        let all = (try? context.fetch(FetchDescriptor<ExchangeDiary>())) ?? []
        if all.contains(where: { $0.id.uuidString == payload.diaryID }) { return .selfSent }
        if let hit = all.first(where: { $0.pairID == payload.pairID }) {
            guard hit.exchangedAt == nil else { return .alreadyExchanged }
            // 同 pair 重寄（对方重新封存了一本）：未拆开前允许替换为最新壳。
            deposit(payload, into: hit)
            try? context.save()
            return .attached(hit)
        }
        return .needsChoice
    }

    /// 把口令落进指定日记本（密封壳）；顺手补全对方档案与「往来的人」。
    static func deposit(_ payload: DiaryPayload, into diary: ExchangeDiary) {
        diary.partnerToken = DiaryToken.reencode(payload)
        if diary.partnerBoxID == nil { diary.partnerBoxID = payload.senderBox }
        if let name = payload.sender, !name.isEmpty, diary.partnerName.isEmpty { diary.partnerName = name }
        PostcardContacts.shared.record(payload.sender, boxID: payload.senderBox,
                                       avatarB64: nil, countryCode: nil, sent: false)
    }

    /// 从对方口令新建一本（收件方零配置：标题/对象/配对码全部从口令带出）。
    static func createFromPayload(_ payload: DiaryPayload, context: ModelContext) -> ExchangeDiary {
        let diary = ExchangeDiary(title: payload.title,
                                  partnerName: payload.sender ?? "",
                                  partnerBoxID: payload.senderBox,
                                  pairID: payload.pairID)
        deposit(payload, into: diary)
        context.insert(diary)
        try? context.save()
        return diary
    }

    /// 可收壳的候选本（选择 sheet 用）：未交换、还没有对方壳的。
    static func candidates(context: ModelContext) -> [ExchangeDiary] {
        let all = (try? context.fetch(FetchDescriptor<ExchangeDiary>())) ?? []
        return all.filter { $0.partnerToken == nil && $0.exchangedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - 封存 / 寄出

    /// 封存：不可撤销；整本口令一次性生成并固化（此后重寄永远同一口令 → 天然幂等）。
    static func seal(_ diary: ExchangeDiary, senderName: String, senderBox: String?, context: ModelContext) {
        guard diary.status == .draft, !diary.entries.isEmpty else { return }
        diary.status = .sealed
        diary.sealedAt = .now
        let tokenID = "d-" + UUID().uuidString.prefix(12).uppercased()
        diary.sealToken = DiaryToken.encode(diary: diary, token: tokenID,
                                            sender: senderName.isEmpty ? nil : senderName,
                                            senderBox: senderBox)
        try? context.save()
        // 记进「我分享出去的」——剪贴板被动探测不弹自己的口令。
        PostcardInbox.shared.markShared(tokenID)
    }

    /// 拆开对方的日记（仪式时刻）：置 exchangedAt 并返回解码好的对方日记。
    static func unseal(_ diary: ExchangeDiary, context: ModelContext) -> DiaryPayload? {
        guard diary.canUnseal, let raw = diary.partnerToken,
              let payload = DiaryToken.decode(raw) else { return nil }
        diary.exchangedAt = .now
        try? context.save()
        return payload
    }
}
