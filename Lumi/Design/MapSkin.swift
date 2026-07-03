import SwiftUI

/// 地图皮肤（Plus 权益）：换点阵地球与真实地图的点亮配色，全局主题不动。
/// - `neon`（霓虹粉紫）：默认，免费。
/// - `aurora`（极光青绿）/ `sunset`（暖阳橙金）：Plus 专属。
/// 存储在 `lumi.mapSkin`；非 Plus 一律回落霓虹（换设备/退订后自动回落，无需迁移）。
enum MapSkin: String, CaseIterable, Identifiable {
    case neon, aurora, sunset

    var id: String { rawValue }
    static let storageKey = "lumi.mapSkin"

    var label: LocalizedStringKey {
        switch self {
        case .neon:   return "霓虹"
        case .aurora: return "极光"
        case .sunset: return "暖阳"
        }
    }
    var isFree: Bool { self == .neon }

    /// 皮肤色板：点阵地球（氛围光/光点/点阵四档）+ 真实地图（点亮填色/描边）。
    struct Palette {
        let glow: Color                      // 氛围辐射光
        let pinTop: Color, pinBottom: Color  // 足迹光点渐变
        let dotNear: Color                   // 紧邻足迹的点
        let dotMid: Color                    // 近
        let dotFar: Color                    // 中距过渡
        let dotBase: Color                   // 基线陆地
        let litFill: Color, litStroke: Color // 真实地图点亮国家
    }

    var palette: Palette {
        switch self {
        case .neon:
            return Palette(glow: .nPurple,
                           pinTop: .nPink, pinBottom: .nOrange,
                           dotNear: Color(hex: 0xE59BF0), dotMid: Color(hex: 0xB07FE0),
                           dotFar: Color(hex: 0x6E5FA0), dotBase: Color(hex: 0x46466A),
                           litFill: .nPurple, litStroke: .nPink)
        case .aurora:
            return Palette(glow: Color(hex: 0x14B8A6),
                           pinTop: Color(hex: 0x4DD9FF), pinBottom: Color(hex: 0x22D3A5),
                           dotNear: Color(hex: 0x9BF2E0), dotMid: Color(hex: 0x3ECFBF),
                           dotFar: Color(hex: 0x2A7E85), dotBase: Color(hex: 0x35506A),
                           litFill: Color(hex: 0x14B8A6), litStroke: Color(hex: 0x4DD9FF))
        case .sunset:
            return Palette(glow: Color(hex: 0xFF9A45),
                           pinTop: Color(hex: 0xFFB84D), pinBottom: Color(hex: 0xFF5E62),
                           dotNear: Color(hex: 0xFFD9A0), dotMid: Color(hex: 0xF5A25D),
                           dotFar: Color(hex: 0x9A6A50), dotBase: Color(hex: 0x584A50),
                           litFill: Color(hex: 0xFF9A45), litStroke: Color(hex: 0xFFB84D))
        }
    }

    /// 从存储值解析（供 @AppStorage 的 raw 字符串换算）；非 Plus 强制霓虹。
    static func resolve(_ raw: String, isPlus: Bool) -> MapSkin {
        guard isPlus else { return .neon }
        return MapSkin(rawValue: raw) ?? .neon
    }
}
