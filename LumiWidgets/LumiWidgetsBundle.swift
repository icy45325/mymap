import WidgetKit
import SwiftUI

/// 小组件扩展入口。后续「StandBy 回放」等新增小组件继续挂这里。
@main
struct LumiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LitCountWidget()
        OnThisDayWidget()
    }
}
