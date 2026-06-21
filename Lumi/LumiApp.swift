import SwiftUI
import SwiftData

/// Lumi v0 应用入口。
///
/// 单一 SwiftData 容器承载三个实体；纯本地、无账号、无网络（搜索地点除外）。
@main
struct LumiApp: App {

    /// 全应用共享的持久化容器。杀进程重启数据不丢（§10 数据与稳定性）。
    let container: ModelContainer = {
        let schema = Schema([Footprint.self, Trip.self, Card.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MapHomeView()
        }
        .modelContainer(container)
    }
}
