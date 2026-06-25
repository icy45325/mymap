import SwiftUI

// ─────────────────────────────────────────────────────────────
//  小组件统一视觉件：让「点亮战绩」与「去年今日」读起来是同一套系统。
//  约定：统一品牌抬头、统一点阵底纹、统一内边距 / 字阶。
// ─────────────────────────────────────────────────────────────

enum WidgetChrome {
    /// 统一内边距（主屏尺寸）。
    static let pad: CGFloat = 16
}

/// 品牌抬头：`LUMI · <栏目>`，两个小组件共用同一字阶。
struct WidgetHeader: View {
    let section: String
    var body: some View {
        Text("LUMI · \(section.localized)")
            .font(.system(size: 10, weight: .semibold)).tracking(2)
            .foregroundStyle(WidgetTheme.muted)
    }
}

/// 点阵底纹：低亮度星图，作为两个小组件共同的品牌肌理。
/// 既是「点亮战绩」的主视觉，也作「去年今日」的淡背景，把两者绑成一家。
struct DotMatrixBackdrop: View {
    let litCodes: [String]
    var opacity: Double = 0.28

    var body: some View {
        DotField(litCodes: litCodes, baseDot: 2.5, litDot: 5)
            .opacity(opacity)
    }
}
