import SwiftUI

/// 地区特色邮票：**点亮过该国即解锁**，寄明信片时可替代基础邮票（空运/陆运/海运）。
/// 存储/口令编码用 `"cc:<ISO2>"`（如 `cc:JP`），与既有 `stampStyle: String` 口径兼容，旧口令不受影响。
/// 全 SwiftUI 原生绘制（白框齿孔 + 主题色内芯 + SF Symbol 地标意象），零位图资源。
struct RegionalStamp: Identifiable, Equatable, Hashable {
    let code: String        // ISO2 国家码（大写）
    let motif: String       // SF Symbol 地标意象
    let inner: Color        // 内芯主色
    let caption: String     // 章上印字（英文，直接印图不本地化）

    var id: String { code }
    /// 存储 / 口令编码值。
    var raw: String { "cc:\(code)" }
    /// 展示名：系统本地化的国家名（中/英/阿免费获得，零新增键）。
    var displayName: String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
    var flag: String {
        code.unicodeScalars.reduce(into: "") { s, c in
            s.unicodeScalars.append(Unicode.Scalar(127397 + c.value)!)
        }
    }

    /// 精选 12 国（图案 = 该国最具辨识度的地标/意象）。
    static let all: [RegionalStamp] = [
        RegionalStamp(code: "JP", motif: "mountain.2.fill",            inner: Color(hex: 0xC0392B), caption: "JAPAN"),
        RegionalStamp(code: "FR", motif: "building.columns.fill",      inner: Color(hex: 0x26418F), caption: "FRANCE"),
        RegionalStamp(code: "IT", motif: "laurel.leading",             inner: Color(hex: 0x1E7A46), caption: "ITALIA"),
        RegionalStamp(code: "GB", motif: "clock.fill",                 inner: Color(hex: 0x8E2430), caption: "UK"),
        RegionalStamp(code: "US", motif: "crown.fill",                 inner: Color(hex: 0x24457A), caption: "USA"),
        RegionalStamp(code: "CN", motif: "building.2.fill",            inner: Color(hex: 0xB3261E), caption: "CHINA"),
        RegionalStamp(code: "AE", motif: "sailboat.fill",              inner: Color(hex: 0x156B4A), caption: "UAE"),
        RegionalStamp(code: "TH", motif: "building.columns.circle.fill", inner: Color(hex: 0xB8860B), caption: "THAILAND"),
        RegionalStamp(code: "EG", motif: "pyramid.fill",               inner: Color(hex: 0xA8742A), caption: "EGYPT"),
        RegionalStamp(code: "AU", motif: "wind",                       inner: Color(hex: 0x1F6B7A), caption: "AUSTRALIA"),
        RegionalStamp(code: "SG", motif: "fish.fill",                  inner: Color(hex: 0x9A2B4A), caption: "SINGAPORE"),
        RegionalStamp(code: "TR", motif: "balloon.fill",               inner: Color(hex: 0x7A3FA0), caption: "TÜRKİYE"),
    ]

    static func byCode(_ code: String) -> RegionalStamp? {
        all.first { $0.code == code.uppercased() }
    }
    /// 已解锁的地区邮票（按已点亮国家码派生，无新增存储）。
    static func unlocked(litCodes: Set<String>) -> [RegionalStamp] {
        all.filter { litCodes.contains($0.code) }
    }
}

/// 邮票的统一类型：基础（空运/陆运/海运）/ 地区特色 / 节日限定。序列化用 `raw` 字符串，双向兼容旧数据。
enum StampKind: Equatable, Hashable, Identifiable {
    case basic(PostcardStamp)
    case regional(RegionalStamp)
    case festival(Festival)
    case premium(PremiumStamp)

    var id: String { raw }
    var raw: String {
        switch self {
        case .basic(let b):    return b.rawValue
        case .regional(let r): return r.raw
        case .festival(let f): return "fest:\(f.rawValue)"
        case .premium(let p):  return p.raw
        }
    }
    /// 是否 Plus 专属（典藏票）；用于权益回落守卫。
    var isPremium: Bool { if case .premium = self { return true }; return false }

    /// 从存储/口令字符串解析；未知值兜底空运（与旧行为一致）。
    init(raw: String) {
        if raw.hasPrefix("cc:"), let r = RegionalStamp.byCode(String(raw.dropFirst(3))) {
            self = .regional(r)
        } else if raw.hasPrefix("fest:"), let f = Festival(rawValue: String(raw.dropFirst(5))) {
            self = .festival(f)
        } else if raw.hasPrefix("prem:"), let p = PremiumStamp.byID(String(raw.dropFirst(5))) {
            self = .premium(p)
        } else {
            self = .basic(PostcardStamp(rawValue: raw) ?? .air)
        }
    }
}

/// 统一邮票视图：按 kind 分发到 基础邮票 / 地区邮票 / 节日章 / 典藏票贴图。
struct StampView: View {
    let kind: StampKind
    var mini: Bool = false

    var body: some View {
        switch kind {
        case .basic(let s):    PostcardStampView(stamp: s, mini: mini)
        case .regional(let r): RegionalStampView(stamp: r, mini: mini)
        case .festival(let f): FestivalSeal(festival: f)
        case .premium(let p):
            Image(p.imageName).resizable().scaledToFit()   // 美术自带票框/齿孔
                .shadow(color: .black.opacity(0.25), radius: mini ? 1 : 2, y: 1)
        }
    }
}

/// 地区邮票绘制：与 `PostcardStampView` 同一框型（白底齿孔 + 虚线内框），内芯换国家主题。
struct RegionalStampView: View {
    let stamp: RegionalStamp
    var mini: Bool = false

    var body: some View {
        let pad: CGFloat = mini ? 3 : 4
        return RoundedRectangle(cornerRadius: 2).fill(.white)
            .overlay {
                ZStack {
                    LinearGradient(colors: [stamp.inner, stamp.inner.opacity(0.78)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 1) {
                        RegionalMotifView(stamp: stamp, fill: .white, accent: stamp.inner)
                            .frame(width: mini ? 13 : 17, height: mini ? 14 : 19)
                        if !mini {
                            Text(verbatim: stamp.caption)
                                .font(.system(size: 5, weight: .bold)).tracking(0.4)
                                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                            Text(verbatim: "LUMI · \(stamp.code)")
                                .font(.system(size: 4)).tracking(0.3)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .overlay(RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                .padding(pad)
            }
            .shadow(color: .black.opacity(0.25), radius: mini ? 1 : 2, y: 1)
    }
}

/// 地标意象：GB / CN / US / SG 用**手绘矢量**（大本钟 / 长城 / 自由女神 / 鱼尾狮，SF Symbol 无对应地标），
/// 其余国家用 SF Symbol。`fill` 为主体色、`accent` 为镂空细节色（钟面 / 鳞片等）。
struct RegionalMotifView: View {
    let stamp: RegionalStamp
    var fill: Color = .white
    var accent: Color = .black

    var body: some View {
        switch stamp.code {
        case "GB", "CN", "US", "SG":
            LandmarkCanvas(code: stamp.code, fill: fill, accent: accent)
        default:
            Image(systemName: stamp.motif)
                .resizable().scaledToFit()
                .foregroundStyle(fill)
        }
    }
}

/// 四国地标的 Canvas 绘制。坐标系归一化自 40×46 设计稿（与预览 SVG 同源）。
private struct LandmarkCanvas: View {
    let code: String
    let fill: Color
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 40, sy = size.height / 46
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
            }
            func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
                var p = Path(); p.move(to: pt(pts[0].0, pts[0].1))
                for q in pts.dropFirst() { p.addLine(to: pt(q.0, q.1)) }
                p.closeSubpath(); return p
            }
            let lw = max(0.6, 1.5 * sx)   // 描边随尺寸缩放，最小可见

            switch code {
            case "GB": drawBigBen(ctx, pt: pt, rect: rect, lw: lw)
            case "CN": drawGreatWall(ctx, pt: pt, rect: rect, poly: poly, lw: lw)
            case "US": drawLiberty(ctx, pt: pt, poly: poly, lw: lw)
            case "SG": drawMerlion(ctx, pt: pt, lw: lw)
            default: break
            }
        }
    }

    // MARK: 大本钟：尖顶 + 钟面 + 塔身竖窗 + 底座
    private func drawBigBen(_ ctx: GraphicsContext,
                            pt: (CGFloat, CGFloat) -> CGPoint,
                            rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
                            lw: CGFloat) {
        var spire = Path(); spire.move(to: pt(20, 1)); spire.addLine(to: pt(15, 9))
        spire.addLine(to: pt(25, 9)); spire.closeSubpath()
        ctx.fill(spire, with: .color(fill))
        ctx.fill(Path(rect(16.5, 9, 7, 4)), with: .color(fill))
        ctx.fill(Path(roundedRect: rect(13, 13, 14, 14), cornerRadius: 1), with: .color(fill))
        ctx.fill(Path(ellipseIn: rect(15, 15, 10, 10)), with: .color(accent))   // 钟面
        var hands = Path()
        hands.move(to: pt(20, 20)); hands.addLine(to: pt(20, 16.6))
        hands.move(to: pt(20, 20)); hands.addLine(to: pt(22.6, 21.4))
        ctx.stroke(hands, with: .color(fill), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        ctx.fill(Path(rect(14.5, 27, 11, 16)), with: .color(fill))              // 塔身
        var windows = Path()
        for x: CGFloat in [17.5, 20, 22.5] { windows.move(to: pt(x, 29)); windows.addLine(to: pt(x, 41)) }
        ctx.stroke(windows, with: .color(accent), lineWidth: lw * 0.7)
        ctx.fill(Path(rect(12.5, 43, 15, 2.5)), with: .color(fill))             // 底座
    }

    // MARK: 长城：烽火台 + 垛口城墙蜿蜒 + 星
    private func drawGreatWall(_ ctx: GraphicsContext,
                               pt: (CGFloat, CGFloat) -> CGPoint,
                               rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
                               poly: ([(CGFloat, CGFloat)]) -> Path,
                               lw: CGFloat) {
        // 星
        ctx.fill(poly([(30, 4), (31.2, 7.4), (34.8, 7.4), (31.9, 9.5), (33, 13),
                       (30, 10.9), (27, 13), (28.1, 9.5), (25.2, 7.4), (28.8, 7.4)]),
                 with: .color(fill))
        // 烽火台
        ctx.fill(Path(rect(5, 16, 10, 4)), with: .color(fill))
        ctx.fill(Path(rect(6.5, 20, 7, 12)), with: .color(fill))
        var crenel = Path()
        crenel.move(to: pt(5, 16)); crenel.addLine(to: pt(6.8, 16)); crenel.addLine(to: pt(6.8, 14))
        crenel.addLine(to: pt(8.6, 14)); crenel.addLine(to: pt(8.6, 16)); crenel.addLine(to: pt(11.4, 16))
        crenel.addLine(to: pt(11.4, 14)); crenel.addLine(to: pt(13.2, 14)); crenel.addLine(to: pt(13.2, 16))
        crenel.addLine(to: pt(15, 16))
        ctx.stroke(crenel, with: .color(fill), lineWidth: lw)
        // 城墙蜿蜒
        var wall = Path()
        wall.move(to: pt(13.5, 26))
        wall.addCurve(to: pt(28, 27), control1: pt(19, 24), control2: pt(23, 24))
        wall.addCurve(to: pt(37, 33), control1: pt(31, 29), control2: pt(34, 32))
        wall.addLine(to: pt(37, 38))
        wall.addCurve(to: pt(21, 31.5), control1: pt(31, 37), control2: pt(26, 34))
        wall.addCurve(to: pt(13.5, 30), control1: pt(18, 30), control2: pt(15.5, 29.5))
        wall.closeSubpath()
        ctx.fill(wall, with: .color(fill))
        // 墙上垛口
        var teeth1 = Path()
        teeth1.move(to: pt(14.5, 25.2)); teeth1.addLine(to: pt(16.5, 24.6)); teeth1.addLine(to: pt(16.2, 22.8))
        teeth1.addLine(to: pt(18.2, 22.4)); teeth1.addLine(to: pt(18.6, 24.2)); teeth1.addLine(to: pt(20.6, 24))
        teeth1.addLine(to: pt(20.6, 22.2)); teeth1.addLine(to: pt(22.6, 22.2)); teeth1.addLine(to: pt(22.6, 24.1))
        ctx.stroke(teeth1, with: .color(fill), lineWidth: lw)
        var teeth2 = Path()
        teeth2.move(to: pt(28.5, 27.6)); teeth2.addLine(to: pt(30, 28.6)); teeth2.addLine(to: pt(31, 27.2))
        teeth2.addLine(to: pt(32.6, 28.4)); teeth2.addLine(to: pt(31.8, 29.8)); teeth2.addLine(to: pt(33.4, 30.9))
        teeth2.addLine(to: pt(34.4, 29.5)); teeth2.addLine(to: pt(36, 30.7)); teeth2.addLine(to: pt(35.2, 32))
        ctx.stroke(teeth2, with: .color(fill), lineWidth: lw * 0.9)
    }

    // MARK: 自由女神：芒冠 + 火炬臂 + 袍身
    private func drawLiberty(_ ctx: GraphicsContext,
                             pt: (CGFloat, CGFloat) -> CGPoint,
                             poly: ([(CGFloat, CGFloat)]) -> Path,
                             lw: CGFloat) {
        var rays = Path()
        rays.move(to: pt(17, 12));   rays.addLine(to: pt(17, 6))
        rays.move(to: pt(13.8, 13.4)); rays.addLine(to: pt(10.4, 9))
        rays.move(to: pt(20.2, 13.4)); rays.addLine(to: pt(23.6, 9))
        rays.move(to: pt(12.6, 16.4)); rays.addLine(to: pt(7.5, 14.4))
        rays.move(to: pt(21.4, 16.4)); rays.addLine(to: pt(26.5, 14.4))
        ctx.stroke(rays, with: .color(fill), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        var head = Path(); head.addEllipse(in: CGRect(x: pt(12.4, 12.9).x, y: pt(12.4, 12.9).y,
                                                      width: pt(21.6, 22.1).x - pt(12.4, 12.9).x,
                                                      height: pt(21.6, 22.1).y - pt(12.4, 12.9).y))
        ctx.fill(head, with: .color(fill))
        ctx.fill(poly([(20.5, 22), (30, 10), (32.6, 12), (23.5, 24)]), with: .color(fill))     // 火炬臂
        var torch = Path(); torch.addEllipse(in: CGRect(x: pt(29, 4.8).x, y: pt(29, 4.8).y,
                                                        width: pt(34.2, 11.6).x - pt(29, 4.8).x,
                                                        height: pt(34.2, 11.6).y - pt(29, 4.8).y))
        ctx.fill(torch, with: .color(fill))
        var flame = Path()
        flame.move(to: pt(31.6, 3))
        flame.addCurve(to: pt(31.6, 6.6), control1: pt(32.8, 4.4), control2: pt(32.6, 5.6))
        flame.addCurve(to: pt(31.6, 3), control1: pt(30.6, 5.6), control2: pt(30.4, 4.4))
        ctx.fill(flame, with: .color(fill))
        ctx.fill(poly([(12, 44), (14.6, 23.5), (19.4, 23.5), (24, 44)]), with: .color(fill))   // 袍身
        ctx.fill(poly([(9.5, 44), (13, 30), (15, 44)]), with: .color(fill.opacity(0.7)))       // 侧褶
    }

    // MARK: 鱼尾狮：狮头（鬃毛锯齿）+ 口喷水柱 + 鱼鳞身 + 底座水线
    private func drawMerlion(_ ctx: GraphicsContext,
                             pt: (CGFloat, CGFloat) -> CGPoint,
                             lw: CGFloat) {
        var body = Path()
        body.move(to: pt(18.5, 4))
        body.addCurve(to: pt(14.2, 7.9), control1: pt(16.6, 4.6), control2: pt(15, 6))
        body.addLine(to: pt(13.4, 9.9)); body.addLine(to: pt(11.6, 12.6)); body.addLine(to: pt(13.5, 13.1))
        body.addLine(to: pt(11.2, 14)); body.addLine(to: pt(12.4, 15.9))
        body.addCurve(to: pt(16.3, 19.1), control1: pt(13.3, 17.4), control2: pt(14.7, 18.5))
        body.addCurve(to: pt(14.5, 27.9), control1: pt(15.2, 21.9), control2: pt(14.6, 24.9))
        body.addCurve(to: pt(16.8, 41.3), control1: pt(14.4, 32.5), control2: pt(15.2, 37))
        body.addLine(to: pt(17.2, 42.4)); body.addLine(to: pt(27.6, 42.4))
        body.addCurve(to: pt(25.2, 29.9), control1: pt(25.9, 38.5), control2: pt(25.1, 34.2))
        body.addCurve(to: pt(26.6, 22.1), control1: pt(25.25, 27.2), control2: pt(25.7, 24.6))
        // 背部鬃毛锯齿
        body.addLine(to: pt(29.4, 23.2)); body.addLine(to: pt(28, 19.9)); body.addLine(to: pt(31.2, 20.3))
        body.addLine(to: pt(29, 17.6)); body.addLine(to: pt(31.9, 16.8)); body.addLine(to: pt(29.2, 14.9))
        body.addLine(to: pt(31.5, 13)); body.addLine(to: pt(28.6, 12.4)); body.addLine(to: pt(29.9, 9.6))
        body.addLine(to: pt(26.9, 10.1)); body.addLine(to: pt(26.8, 6.9)); body.addLine(to: pt(24.1, 8.4))
        body.addCurve(to: pt(18.5, 4), control1: pt(22.9, 5.6), control2: pt(20.9, 3.9))
        body.closeSubpath()
        ctx.fill(body, with: .color(fill))
        // 眼
        ctx.fill(Path(ellipseIn: CGRect(x: pt(15.7, 10.1).x, y: pt(15.7, 10.1).y,
                                        width: pt(17.9, 12.3).x - pt(15.7, 10.1).x,
                                        height: pt(17.9, 12.3).y - pt(15.7, 10.1).y)),
                 with: .color(accent))
        // 口喷水柱 + 水珠
        var jet = Path()
        jet.move(to: pt(11.8, 14.4))
        jet.addCurve(to: pt(5, 22), control1: pt(8.2, 15.2), control2: pt(5.6, 18.2))
        jet.addCurve(to: pt(6, 28.4), control1: pt(4.6, 24.2), control2: pt(5, 26.4))
        ctx.stroke(jet, with: .color(fill), style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: pt(5.4, 29.1).x, y: pt(5.4, 29.1).y,
                                        width: pt(7.6, 31.3).x - pt(5.4, 29.1).x,
                                        height: pt(7.6, 31.3).y - pt(5.4, 29.1).y)), with: .color(fill))
        ctx.fill(Path(ellipseIn: CGRect(x: pt(7.3, 31.2).x, y: pt(7.3, 31.2).y,
                                        width: pt(8.9, 32.8).x - pt(7.3, 31.2).x,
                                        height: pt(8.9, 32.8).y - pt(7.3, 31.2).y)), with: .color(fill))
        // 鱼鳞（两排即可，小尺寸更干净）
        var scales = Path()
        scales.move(to: pt(17, 23.6)); scales.addQuadCurve(to: pt(21.2, 24), control: pt(19, 25.6))
        scales.move(to: pt(20, 24.2)); scales.addQuadCurve(to: pt(24.2, 24.5), control: pt(22, 26))
        scales.move(to: pt(16.3, 28.8)); scales.addQuadCurve(to: pt(20.5, 29.2), control: pt(18.3, 30.8))
        scales.move(to: pt(19.3, 29.4)); scales.addQuadCurve(to: pt(23.5, 29.7), control: pt(21.3, 31.2))
        scales.move(to: pt(16.5, 34)); scales.addQuadCurve(to: pt(20.7, 34.4), control: pt(18.5, 36))
        scales.move(to: pt(19.7, 34.6)); scales.addQuadCurve(to: pt(23.9, 34.9), control: pt(21.7, 36.4))
        ctx.stroke(scales, with: .color(accent), lineWidth: lw * 0.65)
        // 底座水线
        var base = Path()
        base.move(to: pt(12.5, 43.8))
        base.addCurve(to: pt(30.8, 43.8), control1: pt(17.5, 45.2), control2: pt(26, 45.2))
        ctx.stroke(base, with: .color(fill), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
}
