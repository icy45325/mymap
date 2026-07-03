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

/// 邮票的统一类型：基础（空运/陆运/海运）或地区特色。序列化用 `raw` 字符串，双向兼容旧数据。
enum StampKind: Equatable, Hashable, Identifiable {
    case basic(PostcardStamp)
    case regional(RegionalStamp)

    var id: String { raw }
    var raw: String {
        switch self {
        case .basic(let b):    return b.rawValue
        case .regional(let r): return r.raw
        }
    }

    /// 从存储/口令字符串解析；未知值兜底空运（与旧行为一致）。
    init(raw: String) {
        if raw.hasPrefix("cc:"), let r = RegionalStamp.byCode(String(raw.dropFirst(3))) {
            self = .regional(r)
        } else {
            self = .basic(PostcardStamp(rawValue: raw) ?? .air)
        }
    }
}

/// 统一邮票视图：按 kind 分发到基础邮票或地区邮票。
struct StampView: View {
    let kind: StampKind
    var mini: Bool = false

    var body: some View {
        switch kind {
        case .basic(let s):    PostcardStampView(stamp: s, mini: mini)
        case .regional(let r): RegionalStampView(stamp: r, mini: mini)
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
                        Image(systemName: stamp.motif)
                            .font(.system(size: mini ? 10 : 13)).foregroundStyle(.white)
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
