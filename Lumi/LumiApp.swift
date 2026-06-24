import SwiftUI
import SwiftData

/// Lumi v0 应用入口。
///
/// 单一 SwiftData 容器承载三个实体；纯本地、无账号、无网络（搜索地点除外）。
/// 容器收敛到 `LumiStore.shared`，与「点亮这里」App Intent 共用同一实例。
@main
struct LumiApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.system.rawValue

    private var language: AppLanguage { AppLanguage(rawValue: appLanguage) ?? .system }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .applyLanguage(language)
        }
        .modelContainer(LumiStore.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Analytics.log(.appOpen)                       // §9 app_open
                WidgetSync.refresh(LumiStore.shared.mainContext)  // 启动即对齐小组件快照
            }
        }
    }
}
