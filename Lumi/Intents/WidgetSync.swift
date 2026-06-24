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
        let last = footprints.last   // 按 createdAt 升序，末位即最近一次点亮

        let snapshot = LumiSnapshot(
            countries: stats.countries,
            cities: stats.cities,
            worldPercent: Int(stats.worldPercent.rounded()),
            litCountryCodes: stats.litCountryCodes.sorted(),
            lastPlaceName: last?.title,
            lastCountryName: last?.countryName,
            lastVisitedAt: last?.visitedAt,
            updatedAt: .now)

        LumiSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: LumiAppGroup.widgetKind)
    }
}
