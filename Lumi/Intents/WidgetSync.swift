import Foundation
import SwiftData
import WidgetKit

/// 把当前足迹聚合成 `LumiSnapshot` 写进 App Group，并请求小组件刷新。
///
/// 单一出口：点亮（CaptureView / App Intent）、删除、启动对齐都走这里，
/// 保证小组件看到的数字与 App 内 `LumiStats` 口径一致（不另立第二套统计）。
enum WidgetSync {

    /// 从给定 context 重新读取全部足迹 → 生成快照 → 落 App Group → 刷新时间线。
    static func refresh(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Footprint>(sortBy: [SortDescriptor(\.createdAt)])
        let footprints = (try? context.fetch(descriptor)) ?? []
        let stats = LumiStats(footprints: footprints)
        // 「上次你在」按**实际到访时间**（visitedAt）取最近，而非添加顺序
        let last = footprints.max { $0.visitedAt < $1.visitedAt }

        // 精简回忆（按 visitedAt 升序），供「去年今日」按日期匹配。
        let memories = footprints
            .sorted { $0.visitedAt < $1.visitedAt }
            .map { fp in
                LumiMemory(
                    visitedAt: fp.visitedAt,
                    placeName: fp.title,
                    countryName: fp.countryName,
                    countryCode: fp.countryCode,
                    mood: fp.mood.isEmpty ? nil : fp.mood)
            }

        let snapshot = LumiSnapshot(
            countries: stats.countries,
            cities: stats.cities,
            worldPercent: Int(stats.worldPercent.rounded()),
            litCountryCodes: stats.litCountryCodes.sorted(),
            lastPlaceName: last?.title,
            lastCountryName: last?.countryName,
            lastVisitedAt: last?.visitedAt,
            memories: memories,
            updatedAt: .now)

        LumiSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()   // 计数 / 去年今日 / 国旗 三类一起刷新
    }
}
