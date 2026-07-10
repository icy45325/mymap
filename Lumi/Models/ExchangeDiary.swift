import Foundation
import SwiftData

/// 交换日记（带外版）：两个人同一段旅程各写各的，**封存后互相交换才能拆开**。
///
/// 不加服务端表——日记以 `LUMID1:` 口令（复用明信片四通道：剪贴板 / 二维码 /
/// lumi:// 链接+AirDrop / Lumi 邮局直投）整本互寄；「先封存、后拆开」由本地状态机保证：
/// 对方寄来的日记先以原始口令存进 `partnerToken`（密封壳），本机未封存前 UI 不解码展示。
/// 封存是产品约定而非密码学保证（口令为 base64 明文）；照片不随口令传，只留在各自本机。
@Model
final class ExchangeDiary {

    @Attribute(.unique) var id: UUID
    var title: String
    /// 交换对象昵称（可从「往来的人」选入）。
    var partnerName: String
    /// 对方 Lumi 邮箱号（有则可邮局直投）。
    var partnerBoxID: String? = nil
    /// 状态存原始字符串保迁移安全："draft"（可写）/ "sealed"（封存，不可再改）。
    var statusRaw: String = "draft"
    /// 配对码：创建时生成、随口令传给对方；对方寄回时凭它自动对上这本日记。
    var pairID: String
    var createdAt: Date
    var sealedAt: Date? = nil
    var sentAt: Date? = nil
    /// 拆开对方日记的时刻（仪式完成）。
    var exchangedAt: Date? = nil
    /// 封存时一次性生成并固化的整本口令——重寄永远同一口令，天然幂等。
    var sealToken: String? = nil
    /// 对方寄来的原始 LUMID1 口令（密封壳）。拆开前不解码展示。
    var partnerToken: String? = nil
    /// v1.3 共同行程时绑定 Trip 的预留钩子。
    var tripID: UUID? = nil

    @Relationship(deleteRule: .cascade, inverse: \DiaryEntry.diary)
    var entries: [DiaryEntry] = []

    enum Status: String { case draft, sealed }
    var status: Status {
        get { Status(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    /// 对方日记已寄到、且我方已封存 → 可以拆开。
    var canUnseal: Bool { status == .sealed && partnerToken != nil && exchangedAt == nil }
    var isExchanged: Bool { exchangedAt != nil }

    init(title: String, partnerName: String, partnerBoxID: String? = nil, pairID: String? = nil) {
        self.id = UUID()
        self.title = title
        self.partnerName = partnerName
        self.partnerBoxID = partnerBoxID
        self.pairID = pairID ?? "P-" + UUID().uuidString.prefix(8).uppercased()
        self.createdAt = .now
    }
}

/// 日记条目（仅本方所写；对方的条目不落库，从 partnerToken 现解码展示）。
@Model
final class DiaryEntry {

    @Attribute(.unique) var id: UUID
    /// 条目对应的日子（一天可多条）。
    var date: Date
    var text: String
    /// 心情：单个 emoji，可空。
    var mood: String? = nil
    /// 本机相册引用（PHAsset localIdentifier）。**不随口令传**——照片留在各自本机。
    var photoAssetIDs: [String] = []
    var createdAt: Date
    var updatedAt: Date

    var diary: ExchangeDiary?

    init(date: Date = .now, text: String = "", mood: String? = nil) {
        self.id = UUID()
        self.date = date
        self.text = text
        self.mood = mood
        self.createdAt = .now
        self.updatedAt = .now
    }
}
