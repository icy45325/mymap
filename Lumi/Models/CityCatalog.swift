import Foundation
import CoreLocation

/// 预设主要城市：真实地图点国家后，可选地再选一个城市（默认折叠、不选）。
///
/// v1 为**精选离线表**（热门旅行国家的主要城市 + 近似坐标）；未覆盖的国家返回空数组，
/// 此时 UI 不展示城市选择、直接以国家落点。覆盖范围可随需要扩充。
struct PresetCity: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    var id: String { name }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

enum CityCatalog {

    /// 给定 ISO_A2 国家码，返回预设主要城市（无则空）。
    static func cities(for countryCode: String?) -> [PresetCity] {
        guard let code = countryCode?.uppercased() else { return [] }
        return table[code] ?? []
    }

    private static func c(_ n: String, _ la: Double, _ lo: Double) -> PresetCity {
        PresetCity(name: n, latitude: la, longitude: lo)
    }

    private static let table: [String: [PresetCity]] = [
        "AE": [c("Dubai", 25.20, 55.27), c("Abu Dhabi", 24.45, 54.37), c("Sharjah", 25.35, 55.39), c("Al Ain", 24.21, 55.76)],
        "CN": [c("Beijing", 39.90, 116.41), c("Shanghai", 31.23, 121.47), c("Guangzhou", 23.13, 113.26), c("Chengdu", 30.57, 104.07), c("Xi'an", 34.34, 108.94), c("Hangzhou", 30.27, 120.15)],
        "HK": [c("Hong Kong", 22.32, 114.17)],
        "JP": [c("Tokyo", 35.68, 139.69), c("Osaka", 34.69, 135.50), c("Kyoto", 35.01, 135.77), c("Sapporo", 43.06, 141.35), c("Fukuoka", 33.59, 130.40)],
        "KR": [c("Seoul", 37.57, 126.98), c("Busan", 35.18, 129.08), c("Jeju", 33.50, 126.53)],
        "TH": [c("Bangkok", 13.76, 100.50), c("Chiang Mai", 18.79, 98.99), c("Phuket", 7.88, 98.39)],
        "SG": [c("Singapore", 1.35, 103.82)],
        "MY": [c("Kuala Lumpur", 3.14, 101.69), c("Penang", 5.41, 100.33)],
        "ID": [c("Jakarta", -6.21, 106.85), c("Bali (Denpasar)", -8.67, 115.21)],
        "VN": [c("Hanoi", 21.03, 105.85), c("Ho Chi Minh City", 10.82, 106.63), c("Da Nang", 16.05, 108.20)],
        "IN": [c("Delhi", 28.61, 77.21), c("Mumbai", 19.08, 72.88), c("Bengaluru", 12.97, 77.59), c("Jaipur", 26.91, 75.79)],
        "FR": [c("Paris", 48.86, 2.35), c("Nice", 43.70, 7.27), c("Lyon", 45.76, 4.84), c("Marseille", 43.30, 5.37)],
        "GB": [c("London", 51.51, -0.13), c("Edinburgh", 55.95, -3.19), c("Manchester", 53.48, -2.24)],
        "IT": [c("Rome", 41.90, 12.50), c("Milan", 45.46, 9.19), c("Venice", 45.44, 12.32), c("Florence", 43.77, 11.26)],
        "ES": [c("Madrid", 40.42, -3.70), c("Barcelona", 41.39, 2.17), c("Seville", 37.39, -5.99)],
        "DE": [c("Berlin", 52.52, 13.40), c("Munich", 48.14, 11.58), c("Frankfurt", 50.11, 8.68)],
        "CH": [c("Zurich", 47.38, 8.54), c("Geneva", 46.20, 6.14), c("Interlaken", 46.69, 7.85)],
        "NL": [c("Amsterdam", 52.37, 4.90)],
        "GR": [c("Athens", 37.98, 23.73), c("Santorini (Thira)", 36.42, 25.43)],
        "TR": [c("Istanbul", 41.01, 28.98), c("Antalya", 36.90, 30.71), c("Cappadocia (Nevşehir)", 38.62, 34.71)],
        "EG": [c("Cairo", 30.04, 31.24), c("Luxor", 25.69, 32.64)],
        "MA": [c("Marrakesh", 31.63, -7.99), c("Casablanca", 33.57, -7.59)],
        "SA": [c("Riyadh", 24.71, 46.68), c("Jeddah", 21.49, 39.19)],
        "QA": [c("Doha", 25.29, 51.53)],
        "US": [c("New York", 40.71, -74.01), c("Los Angeles", 34.05, -118.24), c("San Francisco", 37.77, -122.42), c("Las Vegas", 36.17, -115.14), c("Chicago", 41.88, -87.63)],
        "CA": [c("Toronto", 43.65, -79.38), c("Vancouver", 49.28, -123.12), c("Montreal", 45.50, -73.57)],
        "MX": [c("Mexico City", 19.43, -99.13), c("Cancún", 21.16, -86.85)],
        "BR": [c("Rio de Janeiro", -22.91, -43.17), c("São Paulo", -23.55, -46.63)],
        "AU": [c("Sydney", -33.87, 151.21), c("Melbourne", -37.81, 144.96), c("Brisbane", -27.47, 153.03)],
        "NZ": [c("Auckland", -36.85, 174.76), c("Queenstown", -45.03, 168.66)],
        "ZA": [c("Cape Town", -33.92, 18.42), c("Johannesburg", -26.20, 28.05)],
    ]
}
