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

    /// 初始视野：以阿布扎比为中心的世界尺度（作者正在 UAE dogfood）。
    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.45, longitude: 54.38),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
    )

    var body: some View {
        // MapReader 提供 screen→coordinate 的换算能力，用于点屏落点。
        MapReader { proxy in
            Map(initialPosition: .region(Self.initialRegion)) {
                // ① 已点亮区域着色（M3 起有数据；M1 为空）
                ForEach(state.litRegions) { region in
                    ForEach(Array(region.rings.enumerated()), id: \.offset) { _, ring in
                        MapPolygon(coordinates: ring)
                            .foregroundStyle(Color.litGlow.opacity(0.32))
                            .stroke(Color.litGlow.opacity(0.9), lineWidth: 1)
                    }
                }
                // ② 足迹点：发光琥珀圆点
                ForEach(state.pins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .center) {
                        FootprintDot()
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

/// 足迹发光点。
private struct FootprintDot: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.litGlow.opacity(0.25))
                .frame(width: 22, height: 22)
                .blur(radius: 4)
            Circle()
                .fill(Color.litGlow)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                .shadow(color: Color.litGlow.opacity(0.9), radius: 6)
        }
    }
}
