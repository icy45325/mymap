import SwiftUI
import CoreLocation

// ─────────────────────────────────────────────────────────────
//  底图抽象层。
//
//  v0 固定 MapKit，但所有"点亮 / 落点 / 着色"都只跟下面这几个
//  与底图无关的值类型打交道。将来换 Mapbox（海外美学）或高德
//  （国内合规底图 + 审图号）只需另写一个 MapProvider，上层不动。
// ─────────────────────────────────────────────────────────────

/// 地图上的一个足迹点（点状打卡：城市 / 单点）。
struct MapPin: Identifiable {
    let id: UUID
    /// 始终 WGS-84；显示前由 provider.displayCoordinate 决定要不要纠偏。
    let coordinate: CLLocationCoordinate2D
}

/// 一块被"点亮"的着色区域（国家级 / UAE 酋长国级）。
///
/// 用一组多边形环（每个环是一串闭合坐标）表示，足以画出含飞地 / 多岛的国家。
/// M3 由 Natural Earth 边界数据填充；M1 阶段恒为空（只有 pin，没有着色）。
struct LitRegion: Identifiable {
    /// 区域码：国家 ISO（如 "AE"）或下钻码（如 "AE-DU"）。
    let id: String
    /// 多边形环集合，每个环是闭合的 WGS-84 坐标序列。
    let rings: [[CLLocationCoordinate2D]]
}

/// 收到明信片的来源点（信封大头针；同一地点多张卡聚合计数）。
struct PostcardMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
}

/// 地图上要绘制的一条航线（从 A 到 B 的一段轨迹 + 交通方式）。
/// 坐标为 WGS-84；由 provider 用大圆弧（geodesic）画在真实底图上。
struct RouteLeg: Identifiable {
    let id: UUID
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let mode: TransportMode
}

/// 一帧地图渲染所需的全部输入。View 只描述"要画什么"，怎么画交给 provider。
struct MapRenderState {
    /// 已点亮区域（去过 · 霓虹粉/紫着色）。
    var litRegions: [LitRegion]
    /// 心愿区域（想去未去 · 霓虹青着色，与点亮区分色）。
    var wishRegions: [LitRegion] = []
    /// 航线（在真实底图上画的大圆弧轨迹；默认空 = 不画）。
    var routes: [RouteLeg] = []
    /// 足迹点（发光圆点）。
    var pins: [MapPin]
    /// 收到明信片的来源点（信封 pin + 计数；默认空 = 不画）。
    var postcardPins: [PostcardMapPin] = []
    /// 用户点屏回调，参数为该屏幕点对应的 WGS-84 坐标。
    var onTapCoordinate: (CLLocationCoordinate2D) -> Void
}

/// 底图提供方。返回 `AnyView` 以便作为存量类型（existential）持有：
/// `let mapProvider: MapProvider = MapKitProvider()`。
protocol MapProvider {
    func makeMapView(_ state: MapRenderState) -> AnyView

    /// 把业务坐标（WGS-84）转成该底图的显示坐标。
    /// MapKit / Mapbox 用 WGS-84 直出；高德底图需转 GCJ-02。v0 默认直出。
    func displayCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D
}

extension MapProvider {
    func displayCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        coordinate
    }
}
