import SwiftUI

// ─────────────────────────────────────────────────────────────
//  Lumi 设计令牌：暗夜地图 + 琥珀点亮。
//  色值与《Lumi 产品与架构总览》HTML 中的 CSS 变量保持一致。
// ─────────────────────────────────────────────────────────────

extension Color {

    // 底色
    static let ink       = Color(hex: 0x0B1018)  // 页面底
    static let panel     = Color(hex: 0x121A26)  // 卡片面
    static let panel2    = Color(hex: 0x0F1620)
    static let line      = Color(hex: 0x22324A)  // 边框
    static let lineSoft  = Color(hex: 0x192536)

    // 文字
    static let textPrimary   = Color(hex: 0xEAEEF5)
    static let textSecondary = Color(hex: 0x9DABC0)
    static let textMuted     = Color(hex: 0x5F6E84)

    // 强调
    static let litGlow    = Color(hex: 0xF6B43E) // 「点亮」签名色（琥珀）
    static let litGlow2   = Color(hex: 0xFFC95E) // 点亮渐变高光
    static let accentRose = Color(hex: 0xFF8E7A) // 情感 / 交换日记
    static let accentCyan = Color(hex: 0x5BC7E6) // 结构 / 技术
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

/// 间距 / 圆角令牌（按需用）。
enum Metrics {
    static let radius:     CGFloat = 14
    static let radiusPill: CGFloat = 100
    static let pad:        CGFloat = 16
}

/// 字体令牌。iOS 上没有 Space Grotesk，用系统 rounded / monospaced 作近似；
/// 将来要精确还原品牌字体，再在这里换成自带字体。
enum Typo {
    /// 计数器、坐标等"工具感"文本
    static func mono(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// 大数字、标题
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
