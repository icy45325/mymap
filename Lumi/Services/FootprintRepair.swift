import Foundation
import SwiftData
import CoreLocation

/// 兜底修复：补全 `countryCode` 为空的足迹。
///
/// 为什么需要：从「录入页搜索 / 当前定位」「点这里」等坐标路径加入的足迹，
/// 国家码＝离线 `Boundaries`（point-in-polygon，1:110m）∥ 搜索结果 `isoCountryCode`。
/// 当落点落在简化多边形的缝隙（近海岸 / 小国 / 边境）且搜索结果又没带国家码时，
/// `countryCode` 会是 nil —— 这条足迹便**不计入国家统计、也进不了国旗小组件**。
/// 这里在启动时（及新增后）对这类足迹做一次补全：先离线判定，仍空则在线反编码兜底。
enum FootprintRepair {

    @MainActor
    static func backfillMissingCountries(_ context: ModelContext) async {
        guard let all = try? context.fetch(FetchDescriptor<Footprint>()) else { return }
        let missing = all.filter { ($0.countryCode ?? "").isEmpty }
        guard !missing.isEmpty else { return }

        var changed = false
        let geocoder = CLGeocoder()

        for fp in missing {
            // 1) 先离线判定（多数情况能补上）
            if let code = Boundaries.shared.countryCode(at: fp.coordinate) {
                fp.countryCode = code
                if code == "AE" { fp.subRegionCode = Boundaries.shared.emirateCode(at: fp.coordinate) }
                changed = true
                continue
            }
            // 2) 离线缝隙 → 在线反编码兜底（best-effort，需网络；拿不到就跳过，不阻断）
            if let placemark = try? await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: fp.latitude, longitude: fp.longitude)).first,
               let iso = placemark.isoCountryCode, !iso.isEmpty {
                fp.countryCode = iso
                if iso == "AE" { fp.subRegionCode = Boundaries.shared.emirateCode(at: fp.coordinate) }
                changed = true
                try? await Task.sleep(for: .milliseconds(120))   // 轻微限流，避免连续反编码被限流
            }
        }

        if changed {
            try? context.save()
            WidgetSync.refresh(context)   // 补全后即时对齐国家统计 / 国旗小组件
        }
    }
}
