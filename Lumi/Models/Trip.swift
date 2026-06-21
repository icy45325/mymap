import Foundation
import SwiftData

/// 旅行：一组足迹的归属容器（如「2026 UAE」）。
///
/// v0 不强制建 Trip——足迹可以没有 trip（散点也能点亮）。保留它是为了 v0.x
/// 的「按行程回顾 / 交换日记」打底；现在只做最薄的一层。
@Model
final class Trip {

    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date

    /// 反向关系：删除 Trip 时把足迹的 trip 置空（足迹本身不删，仍点亮）。
    @Relationship(deleteRule: .nullify, inverse: \Footprint.trip)
    var footprints: [Footprint] = []

    init(title: String = "我的旅行") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
    }
}
