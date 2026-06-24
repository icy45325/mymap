import Foundation
import SwiftData

/// 全应用唯一的 SwiftData 容器。
///
/// 为什么是单例：「点亮这里」App Intent 与主 UI 跑在**同一个进程**里
/// （Intent 定义在 App target，未开 `openAppWhenRun` 时由系统在后台拉起 App 进程执行）。
/// 共用同一个 `ModelContainer` 实例，Intent 写入后主界面的 `@Query` 能即时刷新，
/// 也保证两边永远指向同一个本地库文件（§10 数据与稳定性）。
enum LumiStore {

    /// 实体 schema（足迹 / 行程 / 卡片 / 心愿）。新增实体走 SwiftData 轻量自动迁移。
    static let schema = Schema([Footprint.self, Trip.self, Card.self, Wish.self])

    /// 进程级共享容器。杀进程重启数据不丢；冷启动失败直接 fatal（与原入口一致）。
    static let shared: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()
}
