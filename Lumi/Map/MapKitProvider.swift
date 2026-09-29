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

    /// 主题地图色板（主题切换时根视图整树重建）。
    private var skin: AppTheme.Palette { AppTheme.applied.palette }

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
                // ②.5 航线发光底层：宽、半透明（伪 glow）
                ForEach(state.routes) { r in
                    MapPolyline(coordinates: [r.from, r.to], contourStyle: .geodesic)
                        .stroke(Self.categoryColor(r.category).opacity(0.22),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                }
                // ②.6 航线亮芯：细、高亮，按大圆距离分档着色
                ForEach(state.routes) { r in
                    MapPolyline(coordinates: [r.from, r.to], contourStyle: .geodesic)
                        .stroke(Self.categoryColor(r.category),
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
                // ②.7 航线端点涟漪节点
                ForEach(state.routeNodes) { node in
                    Annotation("", coordinate: node.coordinate, anchor: .center) {
                        RouteNodeView()
                    }
                    .annotationTitles(.hidden)
                }
                // ③ 足迹点：发光琥珀圆点
                ForEach(state.pins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .center) {
                        FootprintDot(skin: skin)
                    }
                    .annotationTitles(.hidden)
                }
                // ④ 收到明信片的来源：信封大头针（多张聚合显示计数）
                ForEach(state.postcardPins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                        PostcardPinView(count: pin.count)
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

    // MARK: 航线样式（按大圆距离分档，对齐大屏参考配色）

    /// 分档配色：近程青 / 中程橙 / 洲际粉。
    static func categoryColor(_ c: RouteCategory) -> Color {
        switch c {
        case .near: return Color(hex: 0x00F0FF)
        case .mid:  return Color(hex: 0xFFAA00)
        case .far:  return Color(hex: 0xFF4777)
        }
    }
}

/// 航线端点涟漪节点：亮青实心 + 向外扩散的脉冲环（对齐参考图 effectScatter）。
private struct RouteNodeView: View {
    @State private var pulse = false
    private let cyan = Color(hex: 0x00F0FF)
    var body: some View {
        ZStack {
            Circle()
                .stroke(cyan.opacity(0.7), lineWidth: 1.5)
                .frame(width: 10, height: 10)
                .scaleEffect(pulse ? 2.6 : 1)
                .opacity(pulse ? 0 : 0.8)
            Circle()
                .fill(cyan)
                .frame(width: 6, height: 6)
                .shadow(color: cyan, radius: 5)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// 收到明信片来源大头针：信封气泡 + 尾巴；同地多张右上角标计数。
private struct PostcardPinView: View {
    let count: Int
    var body: some View {
        VStack(spacing: -1) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: [Color.nOrange, Color.nPink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                    .shadow(color: Color.nOrange.opacity(0.7), radius: 5)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text(verbatim: count > 99 ? "99+" : "\(count)")
                        .font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                        .padding(.vertical, 2).padding(.horizontal, 5)
                        .background(Color.nPink, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
                        .offset(x: 9, y: -7)
                }
            }
            Triangle().fill(Color.nPink).frame(width: 9, height: 6)   // 指向坐标的小尾巴
        }
    }
    private struct Triangle: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.closeSubpath()
            return p
        }
    }
}

/// 足迹发光点（霓虹粉→橙渐变 + 白芯）。
private struct FootprintDot: View {
    let skin: AppTheme.Palette
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
