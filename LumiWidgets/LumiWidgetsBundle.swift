import WidgetKit
import SwiftUI

/// 小组件扩展入口。后续「去年今日」「StandBy 回放」等新增小组件都挂这里。
@main
struct LumiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LitCountWidget()
    }
}
