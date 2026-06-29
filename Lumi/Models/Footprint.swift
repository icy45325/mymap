import Foundation
import SwiftData
import CoreLocation

/// 足迹点：v0 的核心实体。一次"点亮"就是一个 Footprint。
///
/// 设计要点：
/// - 坐标**一律以 WGS-84 存储**；要不要转 GCJ-02 是「显示」的事，交给 MapProvider 决定。
/// - 不在 @Model 里存 CLLocationCoordinate2D（它不可直接持久化），只存 lat/lon 两个 Double。
@Model
final class Footprint {

    /// 单条足迹最多可附带的照片数（§验收需求）。
    static let maxPhotos = 21

    // MARK: - 身份
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    // MARK: - 地点（WGS-84）
    var placeName: String
    var latitude: Double
    var longitude: Double

    /// 城市名（点状打卡用，如 "Dubai" / "London"）。计数器「Z 城」按 distinct(cityName) 统计；
    /// 城市是点亮的"点"（足迹 pin），不做区域着色——区域着色只用于国家与 UAE 酋长国。
    var cityName: String?

    /// 由 point-in-polygon 解析得到的 ISO 国家码（点亮世界地图用），如 "AE"
    var countryCode: String?
    /// 下钻区域码（酋长国 / 省 / 大区…），v0 仅 UAE 用，如 "AE-DU"
    var subRegionCode: String?

    // MARK: - 内容
    var visitedAt: Date         // 行程开始日（单日时即当天）
    var endedAt: Date?          // 行程结束日；nil = 单天
    var mood: String            // 一句心情
    var companions: [String]    // 同行人（v0 先存名字字符串）
    var photoAssetIDs: [String] // PhotoKit 本地标识符（v0 不拷贝原图，只引用相册）

    /// 是否为「收到的明信片」（区别于自己点亮）；及寄件人昵称（可空）。
    var isReceived: Bool = false
    var senderName: String? = nil
    /// 收到明信片的时间（仅 isReceived；用于「按接收时间排序」）。
    var receivedAt: Date? = nil
    /// 收到的明信片附带的封面图（经 AirDrop / 链接传来，已压缩）；QR 因容量限制不带图。
    @Attribute(.externalStorage) var receivedCoverData: Data? = nil

    /// 明信片外观（样式 + 邮票）；收到的卡保存寄件方所选，明信片墙按样式呈现。
    var postcardStyle: String = "vintage"
    var stampStyle: String = "air"

    /// 入境方式（air/land/sea）：护照入境章据此显示 空运✈️/陆运🚆/海运⛴️。点亮时可选，默认空运。
    var entryMeans: String = "air"

    /// 是否为多天行程。
    var isMultiDay: Bool { endedAt != nil }

    // MARK: - 关系
    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Card.footprint)
    var card: Card?

    // MARK: - 派生
    /// 业务层用的坐标（始终 WGS-84）。显示前再交给 MapProvider.displayCoordinate 转换。
    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    // MARK: - 初始化
    init(placeName: String,
         coordinate: CLLocationCoordinate2D,
         cityName: String? = nil,
         visitedAt: Date = .now,
         endedAt: Date? = nil,
         mood: String = "",
         companions: [String] = [],
         photoAssetIDs: [String] = [],
         trip: Trip? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.placeName = placeName
        self.cityName = cityName
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.visitedAt = visitedAt
        self.endedAt = endedAt
        self.mood = mood
        self.companions = companions
        self.photoAssetIDs = photoAssetIDs
        self.trip = trip
    }
}
