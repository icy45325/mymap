import Foundation
import SwiftData
import SwiftUI

// ─────────────────────────────────────────────────────────────
//  交换日记 v3（PRD v1.0）：本 = 一段旅程 × 一位交换对象；页 = 一个足迹（允许自由页）；
//  半页 = 一位作者在一页上的内容。**揭晓发生在页级别**。
//
//  v1 交换机制 = 本机传递（Hand-off）：我写完封存 → 把手机递给旅伴 → TA 在本机写 →
//  双方都封存后一起拆封。零后端、零账号、全程离线。远程交换留社交阶段。
//
//  守卫规则：永远不扣押用户自己写的内容——我的半页任何时候可读，被封的只有对方那半页。
//  设计文档：docs/design/DESIGN-exchange-diary.md
// ─────────────────────────────────────────────────────────────

/// 日记本：绑定一段 Trip 与一位交换对象。封面/日期/地点/书脊配色全部自动派生，用户零填写。
@Model
final class DiaryBook {

    @Attribute(.unique) var id: UUID
    /// 旅程名（自动生成，如「迪拜之旅」）。
    var title: String
    /// 必绑的旅程（成书时创建/复用 Trip 实体）。
    var tripID: UUID
    /// 交换对象昵称（名字标签档；头像经「往来的人」按名弱关联）。
    var partnerName: String
    /// 书脊配色（自动派生，可换色）。存 hex 字符串。
    var spineColorHex: String
    /// 交换模式：v1 只有 handoff（本机传递）；remote 留社交阶段。
    var modeRaw: String = "handoff"
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DiaryPage.book)
    var pages: [DiaryPage] = []

    init(title: String, tripID: UUID, partnerName: String, spineColorHex: String) {
        self.id = UUID()
        self.title = title
        self.tripID = tripID
        self.partnerName = partnerName
        self.spineColorHex = spineColorHex
        self.createdAt = .now
    }

    var sortedPages: [DiaryPage] { pages.sorted { $0.orderIndex < $1.orderIndex } }

    /// 书级聚合状态（书架卡徽标 + 排序权重）。
    enum ShelfState: Int {
        case revealable = 0     // ✦ 可揭晓（最抢眼）
        case myTurn = 1         // ✍️ 该你了
        case waiting = 2        // 🔒 已封存 · 等 TA
        case revealed = 3       // 已揭晓
        case empty = 4          // 空本子
    }

    var shelfState: ShelfState {
        let states = pages.map(\.state)
        if states.contains(.revealable) { return .revealable }
        if states.contains(.empty) || states.contains(.yourTurn) { return .myTurn }
        if states.contains(.waitingPartner) { return .waiting }
        if !pages.isEmpty, states.allSatisfy({ $0 == .revealed }) { return .revealed }
        return pages.isEmpty ? .empty : .myTurn
    }

    var writtenPageCount: Int { pages.filter { $0.myHalf?.sealedAt != nil }.count }
    var revealedPageCount: Int { pages.filter { $0.state == .revealed }.count }

    var spineColor: Color { Color(hex: UInt32(spineColorHex.dropFirst(), radix: 16) ?? 0xFF4FA3) }

    /// 自动派生书脊色候选（创建时轮转取色，「换个颜色」在这里循环）。
    static let spinePalette = ["#FF4FA3", "#9B5DE5", "#4DD9FF", "#FFA94D", "#34C759", "#2DD4BF"]
}

/// 页：默认绑定一个足迹；允许自由页（footprintID == nil，飞机上/回家路上的心情）。
/// 足迹被删时页降级为自由页，快照字段兜底、已写内容不丢。
@Model
final class DiaryPage {

    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var footprintID: UUID? = nil
    /// 地点名快照（防足迹删除后页面失名）。自由页 = 用户输入或「自由页」。
    var titleSnapshot: String
    var dateSnapshot: Date
    /// 揭晓时刻；nil = 未揭晓。**揭晓后双方半页永久可见、不可再改。**
    var revealedAt: Date? = nil

    var book: DiaryBook?

    @Relationship(deleteRule: .cascade, inverse: \DiaryHalf.page)
    var entries: [DiaryHalf] = []       // ≤ 2（我 / TA）

    init(orderIndex: Int, footprintID: UUID?, titleSnapshot: String, dateSnapshot: Date) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.footprintID = footprintID
        self.titleSnapshot = titleSnapshot
        self.dateSnapshot = dateSnapshot
    }

    var myHalf: DiaryHalf? { entries.first { $0.authorIsOwner } }
    var theirHalf: DiaryHalf? { entries.first { !$0.authorIsOwner } }

    /// 页状态（零冗余，全派生）。
    enum PageState {
        case empty              // 谁都没封
        case waitingPartner     // 仅我封 → 已封存 · 等 TA
        case yourTurn           // 仅对方封 → 该你了
        case revealable         // 双方已封、未揭晓
        case revealed           // 已揭晓
    }

    var state: PageState {
        if revealedAt != nil { return .revealed }
        let mine = myHalf?.sealedAt != nil
        let theirs = theirHalf?.sealedAt != nil
        switch (mine, theirs) {
        case (true, true):   return .revealable
        case (true, false):  return .waitingPartner
        case (false, true):  return .yourTurn
        case (false, false): return .empty
        }
    }
}

/// 半页：一位作者在一页上的内容。文字 / 涂鸦（PencilKit）/ 语音（≤60s m4a）任意组合。
/// sealedAt 非 nil 即已封存（不可再改）；草稿期可随时改。
@Model
final class DiaryHalf {

    @Attribute(.unique) var id: UUID
    /// true = 本机主人；false = 交换对象（本机传递时 TA 在这台手机上写）。
    var authorIsOwner: Bool
    var text: String? = nil
    /// PencilKit PKDrawing.dataRepresentation()。
    @Attribute(.externalStorage) var drawingData: Data? = nil
    /// 语音 m4a（AVAudioRecorder，上限 60 秒）。
    @Attribute(.externalStorage) var voiceData: Data? = nil
    var voiceDuration: Double = 0
    var sealedAt: Date? = nil
    var createdAt: Date
    var updatedAt: Date

    var page: DiaryPage?

    init(authorIsOwner: Bool) {
        self.id = UUID()
        self.authorIsOwner = authorIsOwner
        self.createdAt = .now
        self.updatedAt = .now
    }

    var isEmpty: Bool {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && drawingData == nil && voiceData == nil
    }
}
