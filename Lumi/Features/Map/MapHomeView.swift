import SwiftUI
import SwiftData
import CoreLocation

/// 世界地图主页（v0 核心页）。
///
/// 里程碑路线：
/// - M1：地图渲染 + 点屏落点（本文件已覆盖）
/// - M2：落点持久化（SwiftData，已覆盖）
/// - M3：加载 Natural Earth 边界，给"去过的国家 / UAE 酋长国"着色（见 `litRegions` 的 TODO）
/// - M4：顶部计数器（已接，数据随 M3 的 countryCode 解析自动生效）
/// - M5：FAB 唤起 Capture 录入页（见 `fab` 的 TODO）
struct MapHomeView: View {

    @Environment(\.modelContext) private var context

    /// 所有足迹，按到访时间倒序。
    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    /// 底图 provider —— v0 固定 MapKit。将来换 Mapbox（海外美学）/ 高德（国内合规）只改这一行。
    private let mapProvider: MapProvider = MapKitProvider()

    @State private var showCapture = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.ink.ignoresSafeArea()

            // 地图：点亮区（M3）+ 足迹点，由 provider 渲染
            mapProvider.makeMapView(renderState)
                .ignoresSafeArea()

            counterChip
                .padding(.top, 8)

            fab
        }
    }

    // MARK: - 渲染状态

    private var renderState: MapRenderState {
        MapRenderState(
            litRegions: litRegions,
            pins: footprints.map { MapPin(id: $0.id, coordinate: $0.coordinate) },
            onTapCoordinate: dropFootprint
        )
    }

    /// M3 实现：根据已点亮的国家 / 酋长国码，从 Natural Earth 取边界多边形。
    /// M1 先返回空数组，让地图先跑起来（此时只有足迹 pin，没有区域着色）。
    private var litRegions: [LitRegion] {
        // TODO(M3): Boundaries.shared.regions(forCountryCodes: litCountryCodes,
        //                                      emirateCodes: litEmirateCodes)
        []
    }

    // MARK: - 计数（M4）

    /// 已点亮国家数 = distinct(countryCode)，同国多次到访不重复计数。
    private var litCountryCount: Int {
        Set(footprints.compactMap { $0.countryCode }).count
    }

    /// 已点亮城市数 = distinct(cityName)，城市为点状打卡。
    private var litCityCount: Int {
        Set(footprints.compactMap { $0.cityName }).count
    }

    // MARK: - 子视图

    private var counterChip: some View {
        Text("✦ 已点亮 \(litCountryCount) 国 · \(litCityCount) 城")
            .font(Typo.mono(13))
            .foregroundStyle(Color.litGlow)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.litGlow.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.litGlow.opacity(0.4), lineWidth: 1))
    }

    private var fab: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showCapture = true
                } label: {
                    Label("点亮新足迹", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .background(Color.litGlow, in: Capsule())
                        .foregroundStyle(Color.ink)
                        .shadow(color: Color.litGlow.opacity(0.5), radius: 12)
                }
                .padding(20)
            }
        }
        // TODO(M5): .sheet(isPresented: $showCapture) { CaptureView() }
    }

    // MARK: - 动作

    /// M1/M2：点屏落一个足迹并持久化。
    /// M3 会在这里补：反向地理编码得到 placeName / cityName / countryCode（再驱动着色与计数）。
    private func dropFootprint(at coordinate: CLLocationCoordinate2D) {
        let footprint = Footprint(placeName: "新足迹", coordinate: coordinate)
        context.insert(footprint)

        // 明信片卡已确认持久化：每个足迹同步建一张卡
        context.insert(Card(footprint: footprint))

        try? context.save()
    }
}

#Preview {
    MapHomeView()
        .modelContainer(for: [Footprint.self, Trip.self, Card.self], inMemory: true)
}
