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
        var subRegionCode: String?   // v0 仅 UAE 酋长国（"AE-DU"）
    }

    /// 解析坐标。**国家 / 酋长国码以离线 Boundaries 为准**（point-in-polygon，§5.1），
    /// 地名 / 城市名用 CLGeocoder 补全（best-effort，需网络；拿不到也不阻断）。
    static func resolve(_ coordinate: CLLocationCoordinate2D) async -> Place? {
        // 1) 离线点亮判定（事实来源）
        let countryCode = Boundaries.shared.countryCode(at: coordinate)
        let subRegionCode = countryCode == "AE"
            ? Boundaries.shared.emirateCode(at: coordinate)
            : nil

        // 2) 在线补地名（失败则用兜底名，仍可点亮）
        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude,
                                               longitude: coordinate.longitude)).first

        let placeName = placemark?.name
            ?? placemark?.locality
            ?? placemark?.administrativeArea
            ?? placemark?.country
            ?? "标记的地点"
        let cityName = placemark?.locality ?? placemark?.subAdministrativeArea

        // CLGeocoder 的国家码作为离线判定失败时的兜底（如近海岸 110m 边界外）
        return Place(
            placeName: placeName,
            cityName: cityName,
            countryCode: countryCode ?? placemark?.isoCountryCode,
            subRegionCode: subRegionCode
        )
    }
}
