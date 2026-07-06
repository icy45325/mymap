import SwiftUI
import SwiftData

/// Lumi v0 应用入口。
///
/// 单一 SwiftData 容器承载三个实体；纯本地、无账号、无网络（搜索地点除外）。
/// 容器收敛到 `LumiStore.shared`，与「点亮这里」App Intent 共用同一实例。
@main
struct LumiApp: App {

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 只跟随系统语言：清除历史「应用内语言」覆盖（曾被钉死在某语言）。一次性，避免与系统设置反复打架。
        let d = UserDefaults.standard
        if !d.bool(forKey: "lumi.langOverrideCleared.v1") {
            d.removeObject(forKey: "AppleLanguages")
            d.set(true, forKey: "lumi.langOverrideCleared.v1")
        }
    }

    /// 主题：切换/权益变化时整树重建（.id），令牌缓存已在发布前写好。
    @StateObject private var theme = ThemeStore.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .id(theme.applied)                                            // 主题切换 → 整树按新令牌重建
                .onOpenURL { url in PostcardInbox.shared.handle(url: url) }  // lumi:// 链接 / AirDrop .lumicard 文件
                .task { await PlusStore.shared.start() }                      // 拉产品 + 对齐 Plus 权益
                .task {                                                       // v1.1 Lumi 邮局：开箱 + 收信（未配置时 no-op）
                    await LumiPost.shared.ensureMailbox()
                    await LumiPost.shared.refreshInbox()
                }
                .task { await FootprintRepair.backfillMissingCountries(LumiStore.shared.mainContext) }  // 补全缺国家码的足迹
                .task(priority: .utility) {                                   // 预热世界地图轮廓，避免首次「分享成就报告」冷加载卡顿
                    await Task.detached(priority: .utility) { _ = Boundaries.shared.allCountryRings }.value
                }
        }
        .modelContainer(LumiStore.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Analytics.log(.appOpen)                       // §9 app_open
                WidgetSync.refresh(LumiStore.shared.mainContext)  // 启动即对齐小组件快照
                Task { await LumiPost.shared.refreshInbox() }     // 回前台顺手收信（幂等入库）
            }
        }
    }
}
