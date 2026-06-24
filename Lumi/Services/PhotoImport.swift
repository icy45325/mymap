import Foundation
import Photos
import CoreLocation
import SwiftData

/// 从相册照片的位置元数据，自动归纳出「去过的地方」候选足迹（快速同步历史足迹）。
///
/// 思路（纯本地优先，§5.1 口径一致）：
/// 1. 取相册里带 GPS 的照片；用离线 point-in-polygon 定国家码（不联网、不耗流量）。
/// 2. 按「国家 + 约 0.1° 网格」把邻近照片聚成一处地点，取最早日期作行程日、收集照片 id。
/// 3. 跳过已有足迹覆盖的网格，避免重复导入。
/// 4. 仅对聚类代表点做反向地理编码补地名（数量可控；失败退回国名，不阻断）。
@MainActor
final class PhotoImportService: ObservableObject {

    enum Phase: Equatable { case idle, requesting, denied, scanning, ready, empty }

    @Published private(set) var phase: Phase = .idle
    @Published var candidates: [ImportCandidate] = []
    @Published private(set) var resolving = false

    /// 反向地理编码的聚类上限，避免相册地点过多时长时间等待 / 触发系统限流。
    private let geocodeCap = 80

    /// 入口：申请权限 → 扫描聚类 → 补地名。`existing` 用于跳过已点亮的网格。
    func start(existing: [Footprint]) async {
        phase = .requesting
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            phase = .denied
            return
        }

        phase = .scanning
        let existingCells = Self.cells(of: existing)
        let scanned = await Task.detached(priority: .userInitiated) {
            Self.scan(existingCells: existingCells)
        }.value

        guard !scanned.isEmpty else {
            phase = .empty
            return
        }
        candidates = scanned
        phase = .ready
        await resolveNames()
    }

    /// 把选中的候选落库为 Footprint(+Card)。返回导入条数。
    func importSelected(into context: ModelContext) -> Int {
        let chosen = candidates.filter { $0.selected }
        for c in chosen {
            let fp = Footprint(
                placeName: c.placeName,
                coordinate: c.coordinate,
                cityName: c.cityName,
                visitedAt: c.date,
                photoAssetIDs: c.assetIDs)
            fp.countryCode = c.countryCode
            fp.subRegionCode = c.subRegionCode
            context.insert(fp)
            context.insert(Card(footprint: fp))
        }
        try? context.save()
        return chosen.count
    }

    var selectedCount: Int { candidates.filter(\.selected).count }

    func toggleAll(_ on: Bool) {
        for i in candidates.indices { candidates[i].selected = on }
    }

    // MARK: - 权限

    private func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }
    }

    // MARK: - 扫描聚类（后台线程，纯离线）

    private struct Cluster {
        var earliest: Date
        var latitude: Double
        var longitude: Double
        var country: String?
        var subRegion: String?
        var ids: [String]
    }

    nonisolated private static func scan(existingCells: Set<String>) -> [ImportCandidate] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var groups: [String: Cluster] = [:]
        var order: [String] = []

        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location, let date = asset.creationDate else { return }
            let coord = location.coordinate
            // 离线定国家；落公海 / 无匹配则跳过（与点亮判定同口径）
            guard let country = Boundaries.shared.countryCode(at: coord) else { return }

            let cell = Self.cellKey(country: country, lat: coord.latitude, lon: coord.longitude)
            if existingCells.contains(cell) { return }   // 已有足迹覆盖此处

            if var cluster = groups[cell] {
                if date < cluster.earliest {
                    cluster.earliest = date
                    cluster.latitude = coord.latitude
                    cluster.longitude = coord.longitude
                }
                if cluster.ids.count < 20 { cluster.ids.append(asset.localIdentifier) }
                groups[cell] = cluster
            } else {
                let sub = country == "AE" ? Boundaries.shared.emirateCode(at: coord) : nil
                groups[cell] = Cluster(earliest: date, latitude: coord.latitude,
                                       longitude: coord.longitude, country: country,
                                       subRegion: sub, ids: [asset.localIdentifier])
                order.append(cell)
            }
        }

        return order.compactMap { key -> ImportCandidate? in
            guard let c = groups[key] else { return nil }
            return ImportCandidate(
                countryCode: c.country,
                latitude: c.latitude,
                longitude: c.longitude,
                date: c.earliest,
                placeName: CountryInfo.chineseName(for: c.country) ?? "未知地点",
                cityName: nil,
                subRegionCode: c.subRegion,
                assetIDs: c.ids)
        }
        .sorted { $0.date < $1.date }
    }

    /// 聚类键：国家 + 0.1°(≈11km) 网格，把邻近照片归到同一处地点。
    nonisolated private static func cellKey(country: String, lat: Double, lon: Double) -> String {
        let latR = (lat * 10).rounded() / 10
        let lonR = (lon * 10).rounded() / 10
        return "\(country)|\(latR)|\(lonR)"
    }

    nonisolated private static func cells(of footprints: [Footprint]) -> Set<String> {
        Set(footprints.compactMap { fp in
            guard let code = fp.countryCode else { return nil }
            return cellKey(country: code, lat: fp.latitude, lon: fp.longitude)
        })
    }

    // MARK: - 反向地理编码补地名（在线 best-effort）

    private func resolveNames() async {
        resolving = true
        defer { resolving = false }

        let geocoder = CLGeocoder()
        for index in candidates.indices.prefix(geocodeCap) {
            if Task.isCancelled { return }
            let coord = candidates[index].coordinate
            let placemark = try? await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coord.latitude, longitude: coord.longitude)).first
            if let placemark {
                let city = placemark.locality ?? placemark.subAdministrativeArea
                candidates[index].cityName = city
                candidates[index].placeName = placemark.locality
                    ?? placemark.name
                    ?? placemark.administrativeArea
                    ?? candidates[index].placeName
            }
            try? await Task.sleep(for: .milliseconds(120))   // 顺序请求 + 轻微间隔，避免限流
        }
    }
}

/// 一条导入候选：一处「去过的地方」。坐标存 lat/lon 便于跨线程传递。
struct ImportCandidate: Identifiable, Sendable {
    let id = UUID()
    var countryCode: String?
    var latitude: Double
    var longitude: Double
    var date: Date
    var placeName: String
    var cityName: String?
    var subRegionCode: String?
    var assetIDs: [String]
    var selected: Bool = true

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var photoCount: Int { assetIDs.count }
    var flag: String { CountryInfo.flag(for: countryCode) }
    var countryName: String? { CountryInfo.chineseName(for: countryCode) }
}
