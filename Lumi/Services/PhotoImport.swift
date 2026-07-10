import Foundation
import Photos
import CoreLocation
import SwiftData

/// 聚类粒度：决定相册照片如何归并成「去过的地方」。
enum ImportGranularity: String, CaseIterable, Identifiable {
    case city      // 城市级：同国家 + 城市归一条
    case country   // 国家级：每个国家归一条（取最早一次）

    var id: String { rawValue }
    var label: String { self == .city ? "按城市" : "按国家" }
}

/// 从相册照片位置，自动归纳「去过的地方」。
///
/// 流程（一次性，结果只在 loading 结束后展示，不显示中间过程）：
/// 1. 扫描带 GPS 的照片 → 离线 point-in-polygon 定国家码。
/// 2. 城市网格聚类 + 反向地理编码补**城市级**地名（带缓存）。
/// 3. 同步产出**两套去重结果**：按城市（国家+城市去重）/ 按国家（去重）。
/// 切换粒度只是即时换已算好的结果，不重扫、不重新过滤。
@MainActor
final class PhotoImportService: ObservableObject {

    enum Phase: Equatable { case idle, requesting, denied, scanning, ready, empty }

    @Published private(set) var phase: Phase = .idle
    @Published var candidates: [ImportCandidate] = []
    @Published private(set) var resolving = false
    @Published private(set) var granularity: ImportGranularity = .city

    // 扫描进度（用于 UI 进度条 + 预计剩余时间）
    @Published private(set) var scanTotal: Int = 0     // 需反向地理编码的聚类数
    @Published private(set) var scanDone: Int = 0      // 已完成数
    @Published private(set) var etaSeconds: Int = 0    // 预计剩余秒数
    var scanProgress: Double { scanTotal == 0 ? 0 : Double(scanDone) / Double(scanTotal) }

    /// 单步平均耗时估计（反向地理编码 + 限速 sleep），用于 ETA。
    private let perStepSeconds = 0.32

    private let geocodeCap = 120

    // 扫描/解析缓存
    private var points: [LocatedPhoto] = []
    private var existingCountrySet: Set<String> = []
    private var existingCityKeySet: Set<String> = []
    private var nameCache: [String: ResolvedName] = [:]
    private var cityResult: [ImportCandidate] = []
    private var countryResult: [ImportCandidate] = []

    // MARK: - 入口

    func start(existing: [Footprint]) async {
        guard phase == .idle else { return }   // 只跑一次
        phase = .requesting
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else { phase = .denied; return }

        phase = .scanning
        existingCountrySet = Set(existing.compactMap(\.countryCode))
        existingCityKeySet = Set(existing.compactMap { fp in
            fp.cityName.map { "\(fp.countryCode ?? "")|\($0)" }
        })
        points = await Task.detached(priority: .userInitiated) { Self.scanPoints() }.value
        guard !points.isEmpty else { phase = .empty; return }

        await buildResults()    // loading 期间一次性算好两套去重结果
        candidates = (granularity == .city) ? cityResult : countryResult
        phase = (cityResult.isEmpty && countryResult.isEmpty) ? .empty : .ready
    }

    /// 切换粒度：即时换已算好的结果，不重新扫描/过滤。
    func setGranularity(_ new: ImportGranularity) {
        guard new != granularity else { return }
        granularity = new
        candidates = (new == .city) ? cityResult : countryResult
    }

    /// 落库；跳过已导入项，幂等。`includePhotos` 为真则把识别到的照片一并挂到足迹（丰富时间线）。
    func importSelected(into context: ModelContext, includePhotos: Bool) -> Int {
        let chosen = candidates.filter { $0.selected && !$0.alreadyImported }
        for c in chosen {
            let photos = includePhotos ? Array(c.importPhotoIDs.prefix(Footprint.maxPhotos)) : []
            let fp = Footprint(placeName: c.placeName, coordinate: c.coordinate,
                               cityName: c.cityName, visitedAt: c.date, photoAssetIDs: photos)
            fp.countryCode = c.countryCode
            fp.subRegionCode = c.subRegionCode
            context.insert(fp)
            context.insert(Card(footprint: fp))
        }
        try? context.save()
        return chosen.count
    }

    var selectedCount: Int { candidates.filter { $0.selected && !$0.alreadyImported }.count }

    func toggleAll(_ on: Bool) {
        for i in candidates.indices where !candidates[i].alreadyImported { candidates[i].selected = on }
    }

    /// 单张照片勾选/去勾选（列表预览缩略图点击）。
    func togglePhoto(_ assetID: String, of candidateID: UUID) {
        guard let i = candidates.firstIndex(where: { $0.id == candidateID }) else { return }
        if candidates[i].excludedPhotoIDs.contains(assetID) {
            candidates[i].excludedPhotoIDs.remove(assetID)
        } else {
            candidates[i].excludedPhotoIDs.insert(assetID)
        }
    }

    // MARK: - 权限

    private func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }
    }

    // MARK: - 构建去重结果（geocode 一次，产出两套）

    private func buildResults() async {
        resolving = true
        defer { resolving = false }

        let clusters = Self.cityClusters(points)
        let geocoder = CLGeocoder()
        var named: [ImportCandidate] = []

        // 预估需要联网反向地理编码的步数（未缓存且在配额内），用于进度条与 ETA
        scanTotal = clusters.enumerated().filter { i, c in
            i < geocodeCap && nameCache[Self.cellKey(country: c.country, lat: c.latitude, lon: c.longitude)] == nil
        }.count
        scanDone = 0
        etaSeconds = Int((Double(scanTotal) * perStepSeconds).rounded(.up))

        for (i, c) in clusters.enumerated() {
            if Task.isCancelled { return }
            let key = Self.cellKey(country: c.country, lat: c.latitude, lon: c.longitude)
            var cand = ImportCandidate(
                countryCode: c.country, latitude: c.latitude, longitude: c.longitude,
                date: c.earliest,
                placeName: CountryInfo.localizedName(for: c.country) ?? String(localized: "未知地点"),
                cityName: nil, subRegionCode: c.subRegion, assetIDs: c.ids)

            if let cached = nameCache[key] {
                cand.cityName = cached.city; cand.placeName = cached.place
            } else if i < geocodeCap {
                let pm = try? await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: c.latitude, longitude: c.longitude)).first
                if let pm {
                    // 只到城市级（locality）；不要 POI/街道（name）
                    let city = pm.locality ?? pm.subAdministrativeArea
                    let place = pm.locality ?? pm.administrativeArea ?? cand.placeName
                    cand.cityName = city; cand.placeName = place
                    nameCache[key] = ResolvedName(place: place, city: city)
                }
                try? await Task.sleep(for: .milliseconds(110))
                scanDone += 1
                etaSeconds = Int((Double(max(0, scanTotal - scanDone)) * perStepSeconds).rounded(.up))
            }
            named.append(cand)
        }
        scanDone = scanTotal; etaSeconds = 0

        // 城市去重（国家+城市，最早）
        cityResult = collapse(named) { "\($0.countryCode ?? "")|\($0.cityName ?? $0.placeName)" }
            .map { mark(Self.capPhotos($0), cityLevel: true) }
        // 国家去重（最早；名字=国名）
        countryResult = collapse(named) { $0.countryCode ?? "" }
            .map { c -> ImportCandidate in
                var c = c
                c.cityName = nil
                c.placeName = CountryInfo.localizedName(for: c.countryCode) ?? c.placeName
                return mark(Self.capPhotos(c), cityLevel: false)
            }
    }

    /// 每个地点最多随足迹带 3 张照片（按拍摄顺序取前 3）。在候选收口处截断，
    /// 保证列表预览与最终落库是同一份照片。collapse 内的 prefix(40) 是去重前的池子，保持不动。
    static let maxPhotosPerPlace = 3
    nonisolated private static func capPhotos(_ c: ImportCandidate) -> ImportCandidate {
        var c = c
        c.assetIDs = Array(c.assetIDs.prefix(maxPhotosPerPlace))
        return c
    }

    private func collapse(_ list: [ImportCandidate], key: (ImportCandidate) -> String) -> [ImportCandidate] {
        var byKey: [String: ImportCandidate] = [:]
        var order: [String] = []
        for c in list {
            let k = key(c)
            if var e = byKey[k] {
                if c.date < e.date { e.date = c.date; e.latitude = c.latitude; e.longitude = c.longitude }
                e.assetIDs = Array((e.assetIDs + c.assetIDs).prefix(40))
                byKey[k] = e
            } else {
                byKey[k] = c; order.append(k)
            }
        }
        return order.compactMap { byKey[$0] }.sorted { $0.date < $1.date }
    }

    /// 标记是否已导入（默认不勾选已导入项）。
    private func mark(_ c: ImportCandidate, cityLevel: Bool) -> ImportCandidate {
        var c = c
        let already = cityLevel
            ? existingCityKeySet.contains("\(c.countryCode ?? "")|\(c.cityName ?? c.placeName)")
            : existingCountrySet.contains(c.countryCode ?? "")
        c.alreadyImported = already
        c.selected = !already
        return c
    }

    // MARK: - 扫描 / 聚类（后台、离线）

    private struct Cluster {
        var earliest: Date
        var latitude: Double
        var longitude: Double
        var country: String
        var subRegion: String?
        var ids: [String]
    }

    nonisolated private static func cityClusters(_ points: [LocatedPhoto]) -> [Cluster] {
        var groups: [String: Cluster] = [:]
        var order: [String] = []
        for p in points {
            let key = cellKey(country: p.countryCode, lat: p.latitude, lon: p.longitude)
            if var c = groups[key] {
                if p.date < c.earliest { c.earliest = p.date; c.latitude = p.latitude; c.longitude = p.longitude }
                if c.ids.count < 40 { c.ids.append(p.assetID) }
                groups[key] = c
            } else {
                groups[key] = Cluster(earliest: p.date, latitude: p.latitude, longitude: p.longitude,
                                      country: p.countryCode, subRegion: p.subRegion, ids: [p.assetID])
                order.append(key)
            }
        }
        return order.compactMap { groups[$0] }
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

    private struct ResolvedName { let place: String; let city: String? }
}

/// 一张带定位的照片（扫描中间产物）。
struct LocatedPhoto: Sendable {
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var date: Date
    var subRegion: String?
    var assetID: String
}

/// 一条导入候选：一处「去过的地方」。
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
    var alreadyImported: Bool = false
    /// 用户在预览里单张去勾选的照片（默认全选）。
    var excludedPhotoIDs: Set<String> = []

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    /// 实际会随足迹导入的照片（预览与落库共用同一份口径）。
    var importPhotoIDs: [String] { assetIDs.filter { !excludedPhotoIDs.contains($0) } }
    var photoCount: Int { importPhotoIDs.count }
    var flag: String { CountryInfo.flag(for: countryCode) }
    var countryName: String? { CountryInfo.localizedName(for: countryCode) }
}
