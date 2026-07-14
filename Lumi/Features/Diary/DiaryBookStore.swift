import Foundation
import SwiftData

/// 交换日记 v3 业务逻辑：成书 / 封存半页 / 揭晓 / 自由页。
/// 全部本机（Hand-off 模式）、全程离线；状态零冗余（从 DiaryHalf.sealedAt / DiaryPage.revealedAt 派生）。
@MainActor
enum DiaryBookStore {

    /// 成书：候选旅程 + 交换对象 + 选中的足迹页 → DiaryBook（封面全自动）。
    /// 返回的书已含按时间正序的页；调用方应直接进入第一页写作页（≤3 击落笔）。
    static func createBook(from candidate: TripCandidate, partnerName: String,
                           selectedFootprints: [Footprint], mode: String = "remote",
                           context: ModelContext) -> DiaryBook {
        let trip = TripSuggest.materialize(candidate, context: context)
        let books = (try? context.fetch(FetchDescriptor<DiaryBook>())) ?? []
        // 书脊配色轮转（同架不同色）
        let hex = DiaryBook.spinePalette[books.count % DiaryBook.spinePalette.count]
        let book = DiaryBook(title: candidate.title, tripID: trip.id,
                             partnerName: partnerName, spineColorHex: hex,
                             mode: mode,
                             partnerBoxID: PostcardContacts.shared.contact(named: partnerName)?.boxID)
        context.insert(book)
        for (i, fp) in selectedFootprints.sorted(by: { $0.visitedAt < $1.visitedAt }).enumerated() {
            let page = DiaryPage(orderIndex: i, footprintID: fp.id,
                                 titleSnapshot: fp.title, dateSnapshot: fp.visitedAt)
            page.book = book
            book.pages.append(page)
        }
        try? context.save()
        Analytics.log(.diaryBookCreated(pageCount: book.pages.count))
        return book
    }

    /// 追加自由页（不属于任何地点的心情；也是「足迹被删降级」的归宿形态）。
    static func addFreePage(to book: DiaryBook, title: String, context: ModelContext) -> DiaryPage {
        let page = DiaryPage(orderIndex: (book.pages.map(\.orderIndex).max() ?? -1) + 1,
                             footprintID: nil,
                             titleSnapshot: title.isEmpty ? String(localized: "自由页") : title,
                             dateSnapshot: .now)
        page.book = book
        book.pages.append(page)
        try? context.save()
        return page
    }

    /// 取（或建）某页某一方的半页（写作页进入时用；草稿期可反复编辑）。
    static func half(of page: DiaryPage, mine: Bool, context: ModelContext) -> DiaryHalf {
        if let existing = mine ? page.myHalf : page.theirHalf { return existing }
        let half = DiaryHalf(authorIsOwner: mine)
        half.page = page
        page.entries.append(half)
        try? context.save()
        return half
    }

    /// 封存半页：内容定格不可改。双方都封存后页进入「可揭晓」。
    static func seal(_ half: DiaryHalf, context: ModelContext) {
        guard half.sealedAt == nil, !half.isEmpty else { return }
        half.sealedAt = .now
        half.updatedAt = .now
        try? context.save()
        let type = half.voiceData != nil ? "voice" : (half.drawingData != nil ? "draw" : "text")
        Analytics.log(.diaryEntrySealed(inputType: type))
        // 页变可揭晓 → 动态中心记一条（拆封是回访钩子）
        if let page = half.page, page.state == .revealable, let book = page.book {
            NoticeCenter.shared.add(.diary,
                                    title: String(localized: "与 \(book.partnerName) 的一页可以拆封了 ✦"),
                                    subtitle: page.titleSnapshot,
                                    targetID: book.id.uuidString)
        }
    }

    /// 揭晓一页（任一方点击拆封）：定格，双方内容永久并置、不可再改。
    static func reveal(_ page: DiaryPage, context: ModelContext) {
        guard page.state == .revealable else { return }
        page.revealedAt = .now
        try? context.save()
        let days = Calendar.current.dateComponents(
            [.day],
            from: page.entries.compactMap(\.sealedAt).min() ?? .now,
            to: .now).day ?? 0
        Analytics.log(.diaryPageRevealed(daysToReveal: days))
    }

    /// 删本（允许；已写内容一并删除——调用方需先确认）。
    static func deleteBook(_ book: DiaryBook, context: ModelContext) {
        context.delete(book)
        try? context.save()
    }

    // MARK: - 远程交换（App 内交换：邀请镜像本 / 互发半页）

    /// 收到邀请 → 生成镜像本（同 pairID、同页结构；partner=发起者，视角对调）。幂等：同 pairID 已有本则复用。
    static func mirrorBook(from p: DiaryLinkPayload, context: ModelContext) -> DiaryBook {
        let books = (try? context.fetch(FetchDescriptor<DiaryBook>())) ?? []
        if let hit = books.first(where: { $0.pairID == p.pairID }) { return hit }
        // 镜像本不绑本地 Trip（旅程在对方手机上）；tripID 用占位 UUID，不参与聚类
        let book = DiaryBook(title: p.title ?? String(localized: "交换日记"),
                             tripID: UUID(),
                             partnerName: p.sender ?? "",
                             spineColorHex: p.spineHex ?? DiaryBook.spinePalette[0],
                             mode: "remote", pairID: p.pairID, partnerBoxID: p.senderBox)
        book.inviteSentAt = .now                      // 镜像端视为已互通
        context.insert(book)
        for meta in (p.pages ?? []).sorted(by: { $0.i < $1.i }) {
            let page = DiaryPage(orderIndex: meta.i, footprintID: nil,
                                 titleSnapshot: meta.t, dateSnapshot: meta.d)
            page.book = book
            book.pages.append(page)
        }
        try? context.save()
        PostcardContacts.shared.record(p.sender, boxID: p.senderBox,
                                       avatarB64: nil, countryCode: nil, sent: false)
        return book
    }

    /// 收到对方寄来的半页集 → 按 pairID+orderIndex 落到对应页的「对方半页」（直接封存态）。
    /// 返回落进的本；找不到本（还没收邀请）返回 nil。
    static func applyHalves(_ p: DiaryLinkPayload, context: ModelContext) -> DiaryBook? {
        let books = (try? context.fetch(FetchDescriptor<DiaryBook>())) ?? []
        guard let book = books.first(where: { $0.pairID == p.pairID }) else { return nil }
        for h in p.halves ?? [] {
            guard let page = book.pages.first(where: { $0.orderIndex == h.i }),
                  page.revealedAt == nil else { continue }
            let half = self.half(of: page, mine: false, context: context)
            guard half.sealedAt == nil else { continue }       // 已收过这半页，幂等
            half.text = h.t
            half.drawingData = h.draw.flatMap { Data(base64Encoded: $0) }
            half.voiceData = h.voice.flatMap { Data(base64Encoded: $0) }
            half.voiceDuration = h.vd
            half.sealedAt = h.sealedAt
            half.updatedAt = .now
            if page.state == .revealable {
                NoticeCenter.shared.add(.diary,
                                        title: String(localized: "与 \(book.partnerName) 的一页可以拆封了 ✦"),
                                        subtitle: page.titleSnapshot,
                                        targetID: book.id.uuidString)
            }
        }
        if book.partnerBoxID == nil { book.partnerBoxID = p.senderBox }
        try? context.save()
        PostcardContacts.shared.record(p.sender, boxID: p.senderBox,
                                       avatarB64: nil, countryCode: nil, sent: false)
        return book
    }

    /// 已封存、还没寄给对方的半页（remote 发送打包用）。
    static func pendingHalves(of book: DiaryBook) -> [(page: DiaryPage, half: DiaryHalf)] {
        book.sortedPages.compactMap { page in
            guard let half = page.myHalf, half.sealedAt != nil, half.syncedAt == nil else { return nil }
            return (page, half)
        }
    }

    /// 标记这批半页已寄出。
    static func markSynced(_ halves: [(page: DiaryPage, half: DiaryHalf)], context: ModelContext) {
        for item in halves { item.half.syncedAt = .now }
        try? context.save()
    }

    // MARK: - 半页暂存（半页先于邀请到达 → 排队，镜像本建好后自动补落，全程无需用户操作）

    private static let stashKey = "lumi.diary.halfStash"

    /// 半页找不到对应的本（邀请还在路上）→ 原样暂存进 UserDefaults 队列。
    static func stashHalves(_ p: DiaryLinkPayload) {
        guard let data = try? JSONEncoder().encode(p),
              let json = String(data: data, encoding: .utf8) else { return }
        var queue = UserDefaults.standard.stringArray(forKey: stashKey) ?? []
        guard !queue.contains(json) else { return }        // 同包幂等
        queue.append(json)
        UserDefaults.standard.set(queue, forKey: stashKey)
    }

    /// 建镜像本后遍历暂存队列逐条补落；落成的移除，仍没对上的留队等下一本。
    static func drainStash(context: ModelContext) {
        let queue = UserDefaults.standard.stringArray(forKey: stashKey) ?? []
        guard !queue.isEmpty else { return }
        var remaining: [String] = []
        for json in queue {
            if let data = json.data(using: .utf8),
               let p = try? JSONDecoder().decode(DiaryLinkPayload.self, from: data),
               applyHalves(p, context: context) != nil {
                continue                                   // 落成，出队
            }
            remaining.append(json)
        }
        UserDefaults.standard.set(remaining, forKey: stashKey)
    }

    /// 足迹被删后的降级检查：对应页保留为自由页（快照兜底，内容不丢）。
    static func degradeOrphanPages(context: ModelContext) {
        let books = (try? context.fetch(FetchDescriptor<DiaryBook>())) ?? []
        let fpIDs = Set(((try? context.fetch(FetchDescriptor<Footprint>())) ?? []).map(\.id))
        var dirty = false
        for page in books.flatMap(\.pages) where page.footprintID != nil {
            if !fpIDs.contains(page.footprintID!) {
                page.footprintID = nil
                dirty = true
            }
        }
        if dirty { try? context.save() }
    }
}
