import SwiftUI
import MapKit

/// MapKit 实现的底图（v0 唯一 provider）。
struct MapKitProvider: MapProvider {
    func makeMapView(_ state: MapRenderState) -> AnyView {
        AnyView(LumiMapView(state: state))
    }
}

// MARK: - SwiftUI 地图

/// 暗夜世界地图：着色区 + 足迹点 + 点屏落点。
private struct LumiMapView: View {

    let state: MapRenderState

    /// 地图皮肤（Plus）：点亮区与足迹点配色随皮肤。
    @AppStorage(MapSkin.storageKey) private var skinRaw: String = ""
    @ObservedObject private var plus = PlusStore.shared
    private var skin: MapSkin.Palette { MapSkin.resolve(skinRaw, isPlus: plus.isPlus).palette }

    /// 初始视野：以阿布扎比为中心的世界尺度（作者正在 UAE dogfood）。
    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.45, longitude: 54.38),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
    )

    var body: some View {
        // MapReader 提供 screen→coordinate 的换算能力，用于点屏落点。
        MapReader { proxy in
            Map(initialPosition: .region(Self.initialRegion)) {
                // ① 心愿区域（想去未去）：霓虹青、虚线描边——先画，避免压住点亮区
                ForEach(state.wishRegions) { region in
                    ForEach(Array(region.rings.enumerated()), id: \.offset) { _, ring in
                        MapPolygon(coordinates: ring)
                            .foregroundStyle(Color.nCyan.opacity(0.18))
                            .stroke(Color.nCyan.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                // ② 已点亮区域着色（去过）：霓虹粉/紫（M3 起有数据；M1 为空）
                ForEach(state.litRegions) { region in
                    ForEach(Array(region.rings.enumerated()), id: \.offset) { _, ring in
                        MapPolygon(coordinates: ring)
                            .foregroundStyle(skin.litFill.opacity(0.30))
                            .stroke(skin.litStroke.opacity(0.9), lineWidth: 1)
                    }
                }
                // ③ 足迹点：发光琥珀圆点
                ForEach(state.pins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .center) {
                        FootprintDot(skin: skin)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .preferredColorScheme(.dark)      // 暗夜底图
            .ignoresSafeArea()
            // 点屏 → 该屏幕点的 WGS-84 坐标 → 落点
            .onTapGesture { screenPoint in
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    state.onTapCoordinate(coordinate)
                }
            }
        }
    }
}

/// 足迹发光点（霓虹粉→橙渐变 + 白芯）。
private struct FootprintDot: View {
    let skin: MapSkin.Palette
    var body: some View {
        ZStack {
            Circle()
                .fill(skin.pinTop.opacity(0.28))
                .frame(width: 22, height: 22)
                .blur(radius: 4)
            Circle()
                .fill(LinearGradient(colors: [skin.pinTop, skin.pinBottom],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 12, height: 12)
                .shadow(color: skin.pinTop.opacity(0.9), radius: 6)
            Circle().fill(.white).frame(width: 4, height: 4)
        }
    }
}
