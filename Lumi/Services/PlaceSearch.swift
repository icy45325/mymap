import Foundation
import MapKit

/// 地点搜索（§4.2 第 2 步）。封装 `MKLocalSearch`，需网络（§7 离线时本服务不可用，
/// 但录入不被阻断——用户仍可手填地名）。
@MainActor
final class PlaceSearchService: ObservableObject {

    @Published private(set) var results: [PlaceResult] = []
    @Published private(set) var isSearching = false

    private var task: Task<Void, Never>?

    /// 防抖搜索：每次调用取消上一次。`region` 用于把结果偏向当前视野。
    func search(_ query: String, near region: MKCoordinateRegion?) {
        task?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))   // 防抖
            guard !Task.isCancelled else { return }
            await self?.run(trimmed, region: region)
        }
    }

    func clear() {
        task?.cancel()
        results = []
    }

    private func run(_ query: String, region: MKCoordinateRegion?) async {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems.compactMap(PlaceResult.init)
        } catch {
            guard !Task.isCancelled else { return }
            results = []
        }
    }
}

/// 一条搜索结果，已从 `MKMapItem.placemark` 抽出点亮所需字段。
/// 直接带出 `countryCode` / `cityName`，省去再做一次反向地理编码。
struct PlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let cityName: String?
    let countryCode: String?
    let coordinate: CLLocationCoordinate2D

    init?(_ item: MKMapItem) {
        let placemark = item.placemark
        self.name = item.name ?? placemark.name ?? placemark.title ?? "未知地点"
        self.cityName = placemark.locality ?? placemark.subAdministrativeArea
        self.countryCode = placemark.isoCountryCode
        self.coordinate = placemark.coordinate
    }

    /// 二级描述：城市 · 国家。
    var subtitle: String {
        [cityName, Locale.current.localizedString(forRegionCode: countryCode ?? "")]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
