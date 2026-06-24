import Foundation
import SwiftData
import CoreLocation

/// 心愿地点：想去但还没去的国家 / 城市。与 Footprint 平级的本地实体。
///
/// 与足迹同样**坐标存 WGS-84**、国家码由离线 point-in-polygon 解析；
/// 在真实地图上点选标记，或在心愿单里搜索添加。点亮（真正去过）后可删心愿。
@Model
final class Wish {

    @Attribute(.unique) var id: UUID
    var createdAt: Date

    var placeName: String
    var cityName: String?
    var countryCode: String?
    var latitude: Double
    var longitude: Double
    var note: String

    // MARK: - 派生
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var flag: String { CountryInfo.flag(for: countryCode) }
    var countryName: String? { CountryInfo.chineseName(for: countryCode) }
    /// 展示标题：优先城市，退回地点名。
    var title: String { cityName ?? placeName }

    init(placeName: String,
         coordinate: CLLocationCoordinate2D,
         cityName: String? = nil,
         countryCode: String? = nil,
         note: String = "") {
        self.id = UUID()
        self.createdAt = .now
        self.placeName = placeName
        self.cityName = cityName
        self.countryCode = countryCode
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.note = note
    }
}
