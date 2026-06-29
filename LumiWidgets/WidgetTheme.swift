import SwiftUI

// ─────────────────────────────────────────────────────────────
//  小组件自带的精简调色板。
//
//  小组件是独立 target，看不到主 App 的 Design/Tokens.swift，这里复刻
//  「暗夜霓虹 v2」用到的几个色值，保持与 App 内观感一致（取值同 Tokens.swift）。
// ─────────────────────────────────────────────────────────────

extension Color {
    /// 用 0xRRGGBB 创建颜色（同 App 内 Color(hex:)）。
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum WidgetTheme {
    static let bg     = Color(hex: 0x06060E)
    static let bg2    = Color(hex: 0x0A0A16)
    static let panel  = Color(hex: 0x11111D)
    static let text   = Color(hex: 0xF1F1FA)
    static let muted  = Color(hex: 0x8585A0)
    static let faint  = Color(hex: 0x52526A)
    static let lit = Color(hex: 0xFF3D9A)   // 点亮签名色（霓虹粉，同 App nPink）

    /// 容器底：左深右更深的暗夜渐变。
    static var bgGradient: LinearGradient {
        LinearGradient(colors: [bg2, bg],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 大数字 / 标题用衬线（近似 App 内 Playfair 近似）。
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// ISO_A2 → 国旗 emoji（区域指示符拼合；取值同 App 内 CountryInfo.flag）。
    static func flag(for code: String?) -> String {
        guard let raw = code, raw.count >= 2 else { return "🏳️" }
        let cc = String(raw.prefix(2)).uppercased()
        let base: UInt32 = 0x1F1E6   // 🇦
        var scalars = String.UnicodeScalarView()
        for ascii in cc.unicodeScalars {
            guard ascii.value >= 65, ascii.value <= 90,
                  let s = UnicodeScalar(base + ascii.value - 65) else { return "🏳️" }
            scalars.append(s)
        }
        return String(scalars)
    }
}
