import WidgetKit
import SwiftUI

/// 小组件扩展入口。后续「StandBy 回放」等新增小组件继续挂这里。
@main
struct LumiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LumiWidget()          // 战绩 / 国旗（模式可切）
        FlagWidget()          // 去过的国旗（独立，可直接添加）
        OnThisDayWidget()     // 去年今日
    }
}
