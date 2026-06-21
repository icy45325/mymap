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
/// - M5：FAB 唤起 Capture 录入页（已接，见 `fab` + `.sheet`）
struct MapHomeView: View {

    @Environment(\.modelContext) private var context

    /// 所有足迹，按到访时间倒序。
    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    /// 底图 provider —— v0 固定 MapKit。将来换 Mapbox（海外美学）/ 高德（国内合规）只改这一行。
    private let mapProvider: MapProvider = MapKitProvider()

    @State private var showCapture = false
    @State private var counterPulse = false

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
        .sheet(isPresented: $showCapture) {
            // FAB 进来：无预填坐标，靠搜索 / 定位选点
            CaptureView(source: "fab", prefilledCoordinate: nil)
        }
        // 新增足迹后国家数变化 → 计数器跳动（§4.2 点亮反馈）
        .onChange(of: litCountryCount) { _, _ in pulseCounter() }
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
            .scaleEffect(counterPulse ? 1.18 : 1)
    }

    /// 计数器跳动一下（§4.2 点亮反馈）。
    private func pulseCounter() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { counterPulse = true }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { counterPulse = false }
        }
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
    }

    // MARK: - 动作

    /// 点屏快速落点（§5.1 地图点屏分支）：先即时落库 + 显示 pin，再异步反向地理编码
    /// 补 placeName / cityName / countryCode（驱动计数，M3 起再驱动着色）。
    private func dropFootprint(at coordinate: CLLocationCoordinate2D) {
        Analytics.log(.captureStarted(source: "map"))

        // 点亮前的已有国家集合，用于判断"新国家"（§5.1 计数口径）
        let priorCodes = Set(footprints.compactMap { $0.countryCode })

        let footprint = Footprint(placeName: "标记的地点", coordinate: coordinate)
        context.insert(footprint)
        context.insert(Card(footprint: footprint))     // §4.2：每个足迹同步建一张卡
        try? context.save()

        // 异步补全地名与国家码（CLGeocoder 需网络；失败则保留为未识别国家的散点，不崩溃 §7）
        Task {
            let place = await Geocoding.resolve(coordinate)
            if let place {
                footprint.placeName = place.placeName
                footprint.cityName = place.cityName
                footprint.countryCode = place.countryCode
                try? context.save()
            }
            Analytics.log(.footprintCreated(countryCode: place?.countryCode,
                                            hasPhoto: false, companionsCount: 0))
            if let code = place?.countryCode, !priorCodes.contains(code) {
                Analytics.log(.countryLit(countryCode: code, totalLit: priorCodes.count + 1))
            }
        }
    }
}

#Preview {
    MapHomeView()
        .modelContainer(for: [Footprint.self, Trip.self, Card.self], inMemory: true)
}
