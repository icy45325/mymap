import UIKit

/// 触觉反馈薄封装——命令式调用点用（点亮、收明信片、徽章庆祝等）。
/// 视图内的「切 Tab」「庆祝弹出」用 SwiftUI `.sensoryFeedback`；这里给非视图动作处用。
/// 系统「触感反馈」总开关由 iOS 统一处理，无需 App 干预。
enum Haptics {
    /// 成功类（点亮足迹 / 国家、收下明信片、徽章解锁）。
    @MainActor static func success() {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }

    /// 轻点（分享 / 寄出明信片等次要确认）。
    @MainActor static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }

    /// 选择切换（列表 / 分段切换）。
    @MainActor static func selection() {
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }
}
