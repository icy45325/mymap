import Foundation
import SwiftData

/// 交换日记的配对 / 落壳 / 封存逻辑（纯本地状态机，无服务端）。
/// 群本：一本日记 = 我 + 一个或多个伙伴（DiaryPartner）；同一 sealToken 全员互寄，
/// 壳按人落、按人拆，全部拆完置 exchangedAt。
@MainActor
enum DiaryStore {

    // MARK: - 旧数据迁移（2026-07-10 前的 1:1 字段 → partners）

    /// 旧 1:1 日记本惰性迁移：partnerName/partnerBoxID/partnerToken → 一个 DiaryPartner。
    /// 列表 / 详情 onAppear 各调一次即可，幂等。
    static func migrateIfNeeded(_ diary: ExchangeDiary, context: ModelContext) {
        guard diary.partners.isEmpty, !diary.partnerName.isEmpty else { return }
        let p = DiaryPartner(name: diary.partnerName, boxID: diary.partnerBoxID)
        p.shellToken = diary.partnerToken
        if diary.exchangedAt != nil { p.unsealedAt = diary.exchangedAt }
        if diary.sentAt != nil { p.sentAt = diary.sentAt }
        p.diary = diary
        context.insert(p)
        diary.partnerName = ""          // 旧字段清空，防重复迁移
        diary.partnerToken = nil
        try? context.save()
    }

    // MARK: - 本机身份（过滤「自己」用）

    private static var myName: String {
        (UserDefaults.standard.string(forKey: "lumi.profile.name") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func isSelf(name: String?, box: String?) -> Bool {
        if let box, box == LumiPost.shared.identity?.boxID { return true }
        if let name, !myName.isEmpty, name.caseInsensitiveCompare(myName) == .orderedSame { return true }
        return false
    }

    // MARK: - 收件落壳

    enum AttachResult {
        case selfSent                    // 扫到 / 粘到自己封存的日记口令
        case attached(ExchangeDiary)     // pairID 命中既有日记本，密封壳已落到对应伙伴
        case alreadyOpened               // 该伙伴的壳已拆开过，忽略重寄
        case needsChoice                 // 无命中：请用户选「收进已有本 / 新建一本」
    }

    /// 收到伙伴的日记口令：按 diaryID / pairID 自动归位；两者都不命中交给 UI 选择。
    static func attach(_ payload: DiaryPayload, context: ModelContext) -> AttachResult {
        let all = (try? context.fetch(FetchDescriptor<ExchangeDiary>())) ?? []
        all.forEach { migrateIfNeeded($0, context: context) }
        if all.contains(where: { $0.id.uuidString == payload.diaryID }) { return .selfSent }
        if let hit = all.first(where: { $0.pairID == payload.pairID }) {
            // 找到寄件人对应的伙伴：邮箱号优先，名字兜底；不在名单则追加（群里有人后加入）
            let partner = matchPartner(in: hit, payload: payload)
            guard partner.unsealedAt == nil else { return .alreadyOpened }
            deposit(payload, into: partner)
            try? context.save()
            return .attached(hit)
        }
        return .needsChoice
    }

    /// 在日记本里找到（或追加）寄件人对应的伙伴。
    static func matchPartner(in diary: ExchangeDiary, payload: DiaryPayload) -> DiaryPartner {
        if let box = payload.senderBox,
           let hit = diary.partners.first(where: { $0.boxID == box }) { return hit }
        if let name = payload.sender,
           let hit = diary.partners.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return hit
        }
        let p = DiaryPartner(name: payload.sender ?? "", boxID: payload.senderBox)
        p.diary = diary
        diary.partners.append(p)
        return p
    }

    /// 把口令落进指定伙伴（密封壳）；顺手补全档案与「往来的人」。
    static func deposit(_ payload: DiaryPayload, into partner: DiaryPartner) {
        partner.shellToken = DiaryToken.reencode(payload)
        if partner.boxID == nil { partner.boxID = payload.senderBox }
        if let name = payload.sender, !name.isEmpty, partner.name.isEmpty { partner.name = name }
        PostcardContacts.shared.record(payload.sender, boxID: payload.senderBox,
                                       avatarB64: nil, countryCode: nil, sent: false)
    }

    /// 从伙伴口令新建一本（收件方零配置：标题/配对码/全组名单从口令带出，过滤掉自己）。
    static func createFromPayload(_ payload: DiaryPayload, context: ModelContext) -> ExchangeDiary {
        let diary = ExchangeDiary(title: payload.title, pairID: payload.pairID)
        context.insert(diary)
        // 寄件人是第一位伙伴
        let sender = DiaryPartner(name: payload.sender ?? "", boxID: payload.senderBox)
        sender.diary = diary
        diary.partners.append(sender)
        deposit(payload, into: sender)
        // 名单里的其他成员（过滤自己与寄件人）
        for m in payload.others ?? [] {
            guard !isSelf(name: m.n, box: m.b) else { continue }
            if m.b != nil, m.b == payload.senderBox { continue }
            if let s = payload.sender, m.n.caseInsensitiveCompare(s) == .orderedSame { continue }
            let p = DiaryPartner(name: m.n, boxID: m.b)
            p.diary = diary
            diary.partners.append(p)
        }
        try? context.save()
        return diary
    }

    /// 可收壳的候选本（选择 sheet 用）：未全部交换完的。
    static func candidates(context: ModelContext) -> [ExchangeDiary] {
        let all = (try? context.fetch(FetchDescriptor<ExchangeDiary>())) ?? []
        all.forEach { migrateIfNeeded($0, context: context) }
        return all.filter { $0.exchangedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - 封存 / 寄出 / 拆开

    /// 封存：不可撤销；整本口令一次性生成并固化（此后重寄永远同一口令、全员同一份 → 天然幂等）。
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

    /// 拆开某位伙伴的日记（仪式时刻）：置该伙伴 unsealedAt；全部拆完置 exchangedAt。
    static func unseal(_ partner: DiaryPartner, of diary: ExchangeDiary, context: ModelContext) -> DiaryPayload? {
        guard diary.status == .sealed, let raw = partner.shellToken,
              partner.unsealedAt == nil,
              let payload = DiaryToken.decode(raw) else { return nil }
        partner.unsealedAt = .now
        if diary.partners.allSatisfy({ $0.unsealedAt != nil }) {
            diary.exchangedAt = .now
        }
        try? context.save()
        return payload
    }
}
