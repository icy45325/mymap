import Foundation
import SwiftData
import CoreLocation

/// 交通方式：一段航段/轨迹的出行方式。
/// 驱动地图上航线的颜色与线型（§5），也用于护照入境章的细分。
enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case flight, train, sea, car
    var id: String { rawValue }

    /// 由旧 `Footprint.entryMeans`（air/land/sea）映射。
    /// land 目前无法区分火车/自驾，暂按火车展示（PRD §3.3 待确认 Q1）。
    static func from(entryMeans: String) -> TransportMode {
        switch entryMeans {
        case "air":  return .flight
        case "sea":  return .sea
        case "land": return .train
        default:     return .flight
        }
    }
}

/// 航段：一次旅程里「从 A 到 B 的这一程」，带交通方式。
///
/// 与 `Footprint` 解耦——交通方式属于两点之间的这一段，而非某个到达点（PRD §3）。
/// 坐标一律以 **WGS-84** 存储；显示前交给 `MapProvider.displayCoordinate` 决定是否纠偏。
@Model
final class Leg {

    // MARK: 身份
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// 最后修改时间（云同步 last-write-wins 判定；带默认值 → SwiftData 轻量迁移）。
    var updatedAt: Date = Date()

    // MARK: 交通方式
    /// 存 rawValue，展示用 `mode` 计算属性。
    var modeRaw: String

    // MARK: 起点（WGS-84）
    var fromName: String
    var fromLat: Double
    var fromLon: Double

    // MARK: 终点（WGS-84）
    var toName: String
    var toLat: Double
    var toLon: Double

    // MARK: 时间
    var departAt: Date
    var arriveAt: Date?          // nil = 当日

    // MARK: 内容
    var note: String = ""        // 航班号 / 车次 / 一句心情

    /// 可选关联的足迹点（若起终点来自已点亮城市）。
    var fromFootprintID: UUID?
    var toFootprintID: UUID?

    /// 大圆距离缓存（km，直线估算，统计用；§8）。
    var distanceKmCache: Double?

    /// 可选归属行程（一段轨迹属于哪次旅行）。无反向关系，保持迁移最薄。
    var trip: Trip?

    // MARK: 派生
    var mode: TransportMode {
        get { TransportMode(rawValue: modeRaw) ?? .flight }
        set { modeRaw = newValue.rawValue }
    }
    var fromCoordinate: CLLocationCoordinate2D { .init(latitude: fromLat, longitude: fromLon) }
    var toCoordinate: CLLocationCoordinate2D { .init(latitude: toLat, longitude: toLon) }

    // MARK: 初始化
    init(mode: TransportMode,
         fromName: String, from: CLLocationCoordinate2D,
         toName: String, to: CLLocationCoordinate2D,
         departAt: Date = .now, arriveAt: Date? = nil,
         note: String = "", trip: Trip? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.modeRaw = mode.rawValue
        self.fromName = fromName
        self.fromLat = from.latitude
        self.fromLon = from.longitude
        self.toName = toName
        self.toLat = to.latitude
        self.toLon = to.longitude
        self.departAt = departAt
        self.arriveAt = arriveAt
        self.note = note
        self.trip = trip
    }
}
