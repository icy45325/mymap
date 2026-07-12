import Foundation
import SwiftData

/// 交换日记 v3 业务逻辑：成书 / 封存半页 / 揭晓 / 自由页。
/// 全部本机（Hand-off 模式）、全程离线；状态零冗余（从 DiaryHalf.sealedAt / DiaryPage.revealedAt 派生）。
@MainActor
enum DiaryBookStore {

    /// 成书：候选旅程 + 交换对象 + 选中的足迹页 → DiaryBook（封面全自动）。
    /// 返回的书已含按时间正序的页；调用方应直接进入第一页写作页（≤3 击落笔）。
    static func createBook(from candidate: TripCandidate, partnerName: String,
                           selectedFootprints: [Footprint], context: ModelContext) -> DiaryBook {
        let trip = TripSuggest.materialize(candidate, context: context)
        let books = (try? context.fetch(FetchDescriptor<DiaryBook>())) ?? []
        // 书脊配色轮转（同架不同色）
        let hex = DiaryBook.spinePalette[books.count % DiaryBook.spinePalette.count]
        let book = DiaryBook(title: candidate.title, tripID: trip.id,
                             partnerName: partnerName, spineColorHex: hex)
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
