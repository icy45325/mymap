import Foundation
import Photos
import CoreLocation
import SwiftData

/// 聚类粒度：决定相册照片如何归并成「去过的地方」。
enum ImportGranularity: String, CaseIterable, Identifiable {
    case city      // 城市级：国家 + 约 0.1°(≈11km) 网格，一城约一条
    case country   // 国家级：每个国家归一条（取最早一次）

    var id: String { rawValue }
    var label: String { self == .city ? "按城市" : "按国家" }
}

/// 从相册照片的位置元数据，自动归纳出「去过的地方」候选足迹（快速同步历史足迹）。
///
/// 思路（纯本地优先，§5.1 口径一致）：
/// 1. 取相册里带 GPS 的照片；用离线 point-in-polygon 定国家码（不联网、不耗流量）。
/// 2. 按所选粒度把照片聚成地点，取最早日期作行程日、收集照片 id。
/// 3. 跳过已有足迹覆盖处，避免重复导入。
/// 4. 仅对聚类代表点做反向地理编码补地名（数量可控、带缓存；失败退回国名，不阻断）。
///
/// 切换粒度只在内存里重新聚类，不重扫相册、不重复地理编码（命中地名缓存）。
@MainActor
final class PhotoImportService: ObservableObject {

    enum Phase: Equatable { case idle, requesting, denied, scanning, ready, empty }

    @Published private(set) var phase: Phase = .idle
    @Published var candidates: [ImportCandidate] = []
    @Published private(set) var resolving = false
    @Published private(set) var granularity: ImportGranularity = .city

    /// 反向地理编码上限，避免地点过多时长时间等待 / 触发系统限流。
    private let geocodeCap = 80

    // 扫描后缓存：原始定位照片 + 已有足迹覆盖信息 + 地名缓存。切粒度时复用，不重扫。
    private var points: [LocatedPhoto] = []
    private var existingCells: Set<String> = []
    private var existingCountries: Set<String> = []
    private var nameCache: [String: ResolvedName] = [:]
    private var resolveTask: Task<Void, Never>?

    // MARK: - 入口

    /// 申请权限 → 扫描定位照片 → 按当前粒度聚类 → 补地名。
    func start(existing: [Footprint]) async {
        phase = .requesting
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            phase = .denied
            return
        }

        phase = .scanning
        existingCells = Self.cells(of: existing)
        existingCountries = Set(existing.compactMap(\.countryCode))
        points = await Task.detached(priority: .userInitiated) { Self.scanPoints() }.value

        guard !points.isEmpty else { phase = .empty; return }
        rebuild()
        guard !candidates.isEmpty else { phase = .empty; return }
        phase = .ready
        startResolve()
    }

    /// 切换聚类粒度：仅内存重聚类 + 复用地名缓存，必要时补解析缺的名字。
    func setGranularity(_ new: ImportGranularity) {
        guard new != granularity else { return }
        granularity = new
        rebuild()
        startResolve()
    }

    /// 把选中的候选落库为 Footprint(+Card)。返回导入条数。
    func importSelected(into context: ModelContext) -> Int {
        let chosen = candidates.filter(\.selected)
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

    // MARK: - 聚类（内存内，按粒度）

    private func rebuild() {
        candidates = Self.cluster(points, granularity: granularity,
                                  existingCells: existingCells,
                                  existingCountries: existingCountries)
        // 复用已解析地名，切粒度不闪空名
        for i in candidates.indices {
            if let cached = nameCache[Self.nameKey(candidates[i])] {
                candidates[i].placeName = cached.place
                candidates[i].cityName = cached.city
            }
        }
    }

    nonisolated private static func cluster(_ points: [LocatedPhoto],
                                            granularity: ImportGranularity,
                                            existingCells: Set<String>,
                                            existingCountries: Set<String>) -> [ImportCandidate] {
        var groups: [String: Cluster] = [:]
        var order: [String] = []

        for p in points {
            switch granularity {
            case .city where existingCells.contains(cellKey(country: p.countryCode, lat: p.latitude, lon: p.longitude)):
                continue
            case .country where existingCountries.contains(p.countryCode):
                continue
            default:
                break
            }

            let key = granularity == .city
                ? cellKey(country: p.countryCode, lat: p.latitude, lon: p.longitude)
                : p.countryCode

            if var cluster = groups[key] {
                if p.date < cluster.earliest {
                    cluster.earliest = p.date
                    cluster.latitude = p.latitude
                    cluster.longitude = p.longitude
                }
                if cluster.ids.count < 20 { cluster.ids.append(p.assetID) }
                groups[key] = cluster
            } else {
                groups[key] = Cluster(earliest: p.date, latitude: p.latitude, longitude: p.longitude,
                                      country: p.countryCode, subRegion: p.subRegion, ids: [p.assetID])
                order.append(key)
            }
        }

        return order.compactMap { key -> ImportCandidate? in
            guard let c = groups[key] else { return nil }
            return ImportCandidate(
                countryCode: c.country,
                latitude: c.latitude,
                longitude: c.longitude,
                date: c.earliest,
                placeName: CountryInfo.localizedName(for: c.country) ?? String(localized: "未知地点"),
                cityName: nil,
                subRegionCode: c.subRegion,
                assetIDs: c.ids)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - 扫描定位照片（后台线程，纯离线）

    private struct Cluster {
        var earliest: Date
        var latitude: Double
        var longitude: Double
        var country: String
        var subRegion: String?
        var ids: [String]
    }

    nonisolated private static func scanPoints() -> [LocatedPhoto] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var result: [LocatedPhoto] = []
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location, let date = asset.creationDate else { return }
            let coord = location.coordinate
            guard let country = Boundaries.shared.countryCode(at: coord) else { return }
            let sub = country == "AE" ? Boundaries.shared.emirateCode(at: coord) : nil
            result.append(LocatedPhoto(
                countryCode: country, latitude: coord.latitude, longitude: coord.longitude,
                date: date, subRegion: sub, assetID: asset.localIdentifier))
        }
        return result
    }

    /// 城市聚类键：国家 + 0.1°(≈11km) 网格。
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

    /// 地名缓存键：按代表点 0.1° 网格（名字随位置稳定，与粒度无关）。
    nonisolated private static func nameKey(_ c: ImportCandidate) -> String {
        cellKey(country: c.countryCode ?? "", lat: c.latitude, lon: c.longitude)
    }

    // MARK: - 反向地理编码补地名（在线 best-effort，带缓存）

    private func startResolve() {
        resolveTask?.cancel()
        resolveTask = Task { await resolveNames() }
    }

    private func resolveNames() async {
        resolving = true
        defer { resolving = false }

        let geocoder = CLGeocoder()
        for index in candidates.indices.prefix(geocodeCap) {
            if Task.isCancelled { return }
            let key = Self.nameKey(candidates[index])
            if let cached = nameCache[key] {
                candidates[index].placeName = cached.place
                candidates[index].cityName = cached.city
                continue
            }
            let coord = candidates[index].coordinate
            let placemark = try? await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coord.latitude, longitude: coord.longitude)).first
            if Task.isCancelled { return }
            if let placemark {
                let city = placemark.locality ?? placemark.subAdministrativeArea
                let place = placemark.locality
                    ?? placemark.name
                    ?? placemark.administrativeArea
                    ?? candidates[index].placeName
                candidates[index].cityName = city
                candidates[index].placeName = place
                nameCache[key] = ResolvedName(place: place, city: city)
            }
            try? await Task.sleep(for: .milliseconds(120))   // 顺序请求 + 轻微间隔，避免限流
        }
    }

    private struct ResolvedName { let place: String; let city: String? }
}

/// 一张带定位的照片（扫描中间产物，Sendable 便于跨线程传递）。
struct LocatedPhoto: Sendable {
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var date: Date
    var subRegion: String?
    var assetID: String
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
    var countryName: String? { CountryInfo.localizedName(for: countryCode) }
}
