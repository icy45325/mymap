import Foundation
import CoreLocation

/// 反向地理编码：坐标 → 地名 / 城市 / 国家码。
///
/// 用于"地图点屏落点"与"当前定位建议"两条路径（搜索结果已自带这些字段，走 PlaceResult）。
/// v0 用 `CLGeocoder`（需网络）。M3 起国家级点亮改由离线 point-in-polygon（Natural Earth）
/// 解析，本服务退化为只补 placeName / cityName 的辅助。
enum Geocoding {

    struct Place {
        var placeName: String
        var cityName: String?
        var countryCode: String?
    }

    static func resolve(_ coordinate: CLLocationCoordinate2D) async -> Place? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }
        let name = placemark.name
            ?? placemark.locality
            ?? placemark.administrativeArea
            ?? placemark.country
            ?? "未知地点"
        return Place(
            placeName: name,
            cityName: placemark.locality ?? placemark.subAdministrativeArea,
            countryCode: placemark.isoCountryCode
        )
    }
}
