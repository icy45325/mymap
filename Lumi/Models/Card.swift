import Foundation
import SwiftData

/// 明信片卡：由一个 Footprint 渲染而来的"成品"。
///
/// 已确认：v0 **持久化** Card —— 每个 Footprint 录入时同步建一张卡。
/// 好处：可缓存导出图、支持多模板、为后续分享 / 印刷打底。
@Model
final class Card {

    @Attribute(.unique) var id: UUID
    var templateID: String           // 卡片模板："midnight"（暗夜）/ "passport"（护照）/ "minimal"…
    var cachedImageFilename: String? // 缓存的导出图文件名（可空；按需生成）
    var createdAt: Date

    /// 一张卡对应一个足迹（1:1，反向关系在 Footprint.card）
    var footprint: Footprint?

    init(templateID: String = "midnight", footprint: Footprint? = nil) {
        self.id = UUID()
        self.templateID = templateID
        self.footprint = footprint
        self.createdAt = .now
    }
}
