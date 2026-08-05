import Foundation
import CoreLocation

/// 行政区边界（Natural Earth）。负责两件事（§5.1）：
/// 1. **离线 point-in-polygon**：坐标 → 国家码 / UAE 酋长国码（不需网络，点亮判定的事实来源）。
/// 2. **着色多边形**：给已点亮的国家 / 酋长国生成 `LitRegion` 供地图填充。
///
/// 数据：`admin0.geojson`（110m 国界，ISO_A2）+ `uae_emirates.geojson`（10m UAE admin-1）。
/// 坐标精度 4 位（≈11m），足够 v0 集邮粒度。
final class Boundaries {

    static let shared = Boundaries()

    /// 一个行政区：用一组多边形表示（含飞地 / 多岛）；每个多边形是 [外环, 洞...]。
    private struct Region {
        let id: String          // 国家 ISO（"AE"）或酋长国码（"AE-DU"）
        let name: String?
        let continent: String?  // 仅国家有（成就页洲进度用）
        let polygons: [[[CLLocationCoordinate2D]]]
        /// 经纬度包围盒，point-in-polygon 前的快速剪枝。
        let bbox: (minLon: Double, minLat: Double, maxLon: Double, maxLat: Double)
    }

    private let countries: [Region]
    private let emirates: [Region]

    /// 世界国家总数（计数器全球百分比的分母，§4.1）。
    var totalCountryCount: Int { countries.count }

    /// 各洲国家总数（成就页洲进度条分母，§4.4）。
    private(set) lazy var countriesPerContinent: [String: Int] =
        Dictionary(countries.compactMap(\.continent).map { ($0, 1) }, uniquingKeysWith: +)

    /// 国家码 → 所属大洲。
    private lazy var continentByCountry: [String: String] =
        Dictionary(uniqueKeysWithValues: countries.compactMap { region in
            region.continent.map { (region.id, $0) }
        })

    func continent(forCountryCode code: String) -> String? { continentByCountry[code] }

    private init() {
        countries = Self.load("admin0", idKey: "iso")
        emirates  = Self.load("uae_emirates", idKey: "iso")
    }

    // MARK: - 点亮判定（坐标 → 区域码）

    /// 坐标落在哪个国家（ISO_A2）；落公海 / 无匹配返回 nil（§5.1 兜底分支）。
    func countryCode(at coordinate: CLLocationCoordinate2D) -> String? {
        region(containing: coordinate, in: countries)?.id
    }

    /// 坐标落在哪个 UAE 酋长国（"AE-DU"）；非 UAE 返回 nil。
    func emirateCode(at coordinate: CLLocationCoordinate2D) -> String? {
        region(containing: coordinate, in: emirates)?.id
    }

    private func region(containing point: CLLocationCoordinate2D, in regions: [Region]) -> Region? {
        for region in regions {
            guard point.longitude >= region.bbox.minLon, point.longitude <= region.bbox.maxLon,
                  point.latitude  >= region.bbox.minLat, point.latitude  <= region.bbox.maxLat
            else { continue }
            for polygon in region.polygons where Self.contains(point, polygon: polygon) {
                return region
            }
        }
        return nil
    }

    // MARK: - 着色区域生成

    /// 给已点亮的国家与酋长国生成填充多边形。
    /// UAE 下钻到酋长国级：不画整个 AE，改画已点亮的各酋长国（§5.1）。
    func regions(forCountryCodes countryCodes: Set<String>, emirateCodes: Set<String>) -> [LitRegion] {
        var result: [LitRegion] = []

        for region in countries where countryCodes.contains(region.id) && region.id != "AE" {
            result.append(LitRegion(id: region.id, rings: outerRings(of: region)))
        }
        for region in emirates where emirateCodes.contains(region.id) {
            result.append(LitRegion(id: region.id, rings: outerRings(of: region)))
        }
        return result
    }

    /// 全部国家的外环（世界地图底图用：画全部国家、再把已点亮的着色）。
    /// 缓存一次，避免重复展开多边形。
    private(set) lazy var allCountryRings: [LitRegion] =
        countries.map { LitRegion(id: $0.id, rings: outerRings(of: $0)) }

    /// UN 会员国数（汇总「X / 193」用）。territory/属地不计入，故与 totalCountryCount 不同。
    let unMemberCount = 193

    /// 取每个多边形的外环用于着色（v0 不挖洞，飞地洞口忽略，集邮够用）。
    private func outerRings(of region: Region) -> [[CLLocationCoordinate2D]] {
        region.polygons.compactMap { $0.first }
    }

    // MARK: - 射线法 point-in-polygon

    /// 点是否在多边形内：在外环内、且不在任何洞内。
    private static func contains(_ point: CLLocationCoordinate2D, polygon: [[CLLocationCoordinate2D]]) -> Bool {
        guard let outer = polygon.first, rayCast(point, ring: outer) else { return false }
        for hole in polygon.dropFirst() where rayCast(point, ring: hole) { return false }
        return true
    }

    private static func rayCast(_ p: CLLocationCoordinate2D, ring: [CLLocationCoordinate2D]) -> Bool {
        guard ring.count > 2 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i], b = ring[j]
            if (a.latitude > p.latitude) != (b.latitude > p.latitude) {
                let slope = (p.latitude - a.latitude) / (b.latitude - a.latitude)
                let x = a.longitude + slope * (b.longitude - a.longitude)
                if p.longitude < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    // MARK: - GeoJSON 加载

    private static func load(_ resource: String, idKey: String) -> [Region] {
        // 数据内嵌在 BoundaryData（base64 常量），不依赖任何资源打包。
        let data: Data
        switch resource {
        case "admin0":        data = BoundaryData.admin0
        case "uae_emirates":  data = BoundaryData.uaeEmirates
        default:              data = Data()
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]]
        else {
            assertionFailure("边界数据解析失败: \(resource)")
            return []
        }

        return features.compactMap { feature -> Region? in
            guard let props = feature["properties"] as? [String: Any],
                  let id = props[idKey] as? String,
                  let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String
            else { return nil }

            let polygons: [[[CLLocationCoordinate2D]]]
            switch type {
            case "Polygon":
                guard let rings = geometry["coordinates"] as? [[[Double]]] else { return nil }
                polygons = [parseRings(rings)]
            case "MultiPolygon":
                guard let polys = geometry["coordinates"] as? [[[[Double]]]] else { return nil }
                polygons = polys.map(parseRings)
            default:
                return nil
            }

            let coords = polygons.flatMap { $0.flatMap { $0 } }
            guard !coords.isEmpty else { return nil }
            let lons = coords.map(\.longitude), lats = coords.map(\.latitude)
            let bbox = (lons.min()!, lats.min()!, lons.max()!, lats.max()!)

            return Region(id: id,
                          name: props["name"] as? String,
                          continent: props["continent"] as? String,
                          polygons: polygons,
                          bbox: bbox)
        }
    }

    /// GeoJSON 坐标是 [lon, lat]，转成 CLLocationCoordinate2D。
    private static func parseRings(_ rings: [[[Double]]]) -> [[CLLocationCoordinate2D]] {
        rings.map { ring in
            ring.compactMap { pair in
                pair.count >= 2 ? CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0]) : nil
            }
        }
    }
}
