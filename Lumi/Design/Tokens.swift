import SwiftUI

// ─────────────────────────────────────────────────────────────
//  Lumi 设计令牌：暗夜霓虹 v2（Dot-Matrix）。
//  色值与原型 `lumi_style1_v2_dotmatrix.html` 的 CSS 变量保持一致。
//
//  迁移说明：v0 旧「琥珀」令牌名（ink / litGlow / panel…）保留为别名，
//  统一映射到霓虹调色板，存量视图无需改名即可获得新观感。
// ─────────────────────────────────────────────────────────────

extension Color {

    // MARK: 霓虹调色板（原型 :root）
    //  注意：品牌强调色用 n 前缀（nPink…），避免与 SwiftUI 内置 Color.pink/.purple/.cyan/.orange 冲突。
    static let bg     = Color(hex: 0x06060E)  // 页面底
    static let bg2    = Color(hex: 0x0A0A16)
    static let panel  = Color(hex: 0x11111D)  // 卡片面
    static let panel2 = Color(hex: 0x171726)
    static let line   = Color(hex: 0x252537)  // 边框
    static let hair   = Color(hex: 0x1C1C2B)  // 细分隔

    static let text   = Color(hex: 0xF1F1FA)
    static let muted  = Color(hex: 0x8585A0)
    static let faint  = Color(hex: 0x52526A)

    // 四强调槽位随主题（AppTheme/ThemeCache）动态取值；切主题时根视图整树重建。
    static var nPink:   Color { ThemeCache.primary }    // 签名色（足迹 / 主强调）
    static var nPurple: Color { ThemeCache.secondary }
    static var nOrange: Color { ThemeCache.warm }
    static var nCyan:   Color { ThemeCache.cool }
    static let grn     = Color(hex: 0x37E0A0)           // 成功色不随主题

    static let glass  = Color.white.opacity(0.045)

    // MARK: 旧令牌别名（保持存量视图编译；随主题动态）
    static let ink           = bg
    static let lineSoft      = hair
    static let textPrimary   = text
    static let textSecondary = muted
    static let textMuted     = faint
    static var litGlow:    Color { nPink }     // 「点亮」签名色
    static var litGlow2:   Color { nOrange }   // 渐变高光
    static var accentRose: Color { nPink }
    static var accentCyan: Color { nCyan }
}

extension ShapeStyle where Self == LinearGradient {
    /// 品牌主渐变：粉 → 紫 → 橙（原型 --grad）。
    static var neon: LinearGradient {
        LinearGradient(colors: [.nPink, .nPurple, .nOrange],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// 横向主渐变（进度条 / 按钮）。
    static var neonH: LinearGradient {
        LinearGradient(stops: [.init(color: .nPink, location: 0),
                               .init(color: .nPurple, location: 0.55),
                               .init(color: .nOrange, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

extension Color {
    /// 用 0xRRGGBB 形式的十六进制创建颜色。
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// 间距 / 圆角令牌。
enum Metrics {
    static let radius:     CGFloat = 20   // 原型 --r
    static let radiusCard: CGFloat = 18
    static let radiusPill: CGFloat = 100
    static let pad:        CGFloat = 16
}

/// 字体令牌。
/// 原型用 Playfair Display（衬线，标题）+ Inter（正文）。iOS 未内置这两款，
/// 标题用 `.serif` 设计近似 Playfair，正文用系统字；要精确还原再自带字体文件。
enum Typo {
    /// 大标题 / 大数字（衬线，近似 Playfair Display）。
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// 兼容旧调用：等同 serif。
    static func display(_ size: CGFloat) -> Font { serif(size) }
    /// 计数 / 坐标等等宽文本。
    static func mono(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - 可复用样式

extension View {
    /// 玻璃卡片底（霓虹面板 + 细边框）。
    func panelCard(_ radius: CGFloat = Metrics.radiusCard) -> some View {
        background(Color.panel, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.line, lineWidth: 1))
    }
}
