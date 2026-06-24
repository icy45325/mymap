import AppIntents
import SwiftData
import CoreLocation

/// 「点亮这里」——把「记一个足迹」做成 App Intent。
///
/// 一份代码同时喂给 Siri / Spotlight / 快捷指令 / 锁屏 & 控制中心按钮（纪要 §0）：
/// 取当前定位 → 反解地名 + 离线国家判定 → 落 `Footprint`(+`Card`) → 刷新小组件。
/// `openAppWhenRun = false`：不打断当前场景，在后台静默点亮后用对话回执。
struct LightUpHereIntent: AppIntent {

    static var title: LocalizedStringResource = "点亮这里"
    static var description = IntentDescription(
        "用当前位置点亮一个新足迹，无需打开 App。",
        categoryName: "足迹")

    /// 后台执行，不前台拉起 App。
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1) 当前定位（一次性）。无权限 / 拿不到则报可读错误，不静默失败。
        guard let coordinate = await LocationService().requestOnce() else {
            throw LightUpError.locationUnavailable
        }

        // 2) 反解地名（在线 best-effort）+ 离线国家判定（事实来源，§5.1）。
        let place = await Geocoding.resolve(coordinate)

        // 3) 落库。共用进程级容器，与主 UI 即时一致。
        let context = LumiStore.shared.mainContext
        let prior = (try? context.fetch(FetchDescriptor<Footprint>())) ?? []
        let priorCodes = Set(prior.compactMap { $0.countryCode })

        let footprint = Footprint(
            placeName: place?.placeName ?? "我的位置",
            coordinate: coordinate,
            cityName: place?.cityName)
        footprint.countryCode = place?.countryCode
        footprint.subRegionCode = place?.subRegionCode
        context.insert(footprint)
        context.insert(Card(footprint: footprint))   // §4.2 同步建卡
        try? context.save()

        // 4) 埋点（§9）：与录入页同口径。
        Analytics.log(.footprintCreated(countryCode: footprint.countryCode,
                                        hasPhoto: false, companionsCount: 0))
        let isNewCountry = footprint.countryCode.map { !priorCodes.contains($0) } ?? false
        if let code = footprint.countryCode, isNewCountry {
            Analytics.log(.countryLit(countryCode: code, totalLit: priorCodes.count + 1))
        }

        // 5) 刷新小组件快照。
        WidgetSync.refresh(context)

        // 6) 回执对话。
        let name = footprint.countryName ?? footprint.title
        let dialog: IntentDialog = isNewCountry
            ? "已点亮 \(name) ✦ 又解锁一个新国家！"
            : "已点亮 \(footprint.title) ✦"
        return .result(dialog: dialog)
    }
}

/// Intent 错误（向用户展示可读文案）。
enum LightUpError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case locationUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .locationUnavailable:
            return "拿不到当前位置，请在「设置 › 隐私 › 定位服务」里允许 Lumi 后再试。"
        }
    }
}
