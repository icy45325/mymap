import Foundation
import OSLog

/// v0 埋点（§9）：纯本地、单人，落 `OSLog` 即可，无需上报后端。
/// 作者用 Console.app 过滤 subsystem `com.lumi.v0` 自我观察留存。
enum Analytics {

    private static let logger = Logger(subsystem: "com.lumi.v0", category: "analytics")

    enum Event {
        case appOpen
        case captureStarted(source: String)                  // map / fab
        case captureAbandoned(filledFields: Int)
        case footprintCreated(countryCode: String?, hasPhoto: Bool, companionsCount: Int)
        case countryLit(countryCode: String, totalLit: Int)  // 点亮一个**新**国家
        case timelineViewed(footprintCount: Int)
        case statsViewed(totalLit: Int, percent: Int)

        var name: String {
            switch self {
            case .appOpen:           return "app_open"
            case .captureStarted:    return "capture_started"
            case .captureAbandoned:  return "capture_abandoned"
            case .footprintCreated:  return "footprint_created"
            case .countryLit:        return "country_lit"
            case .timelineViewed:    return "timeline_viewed"
            case .statsViewed:       return "stats_viewed"
            }
        }

        var props: [String: String] {
            switch self {
            case .appOpen:
                return [:]
            case let .captureStarted(source):
                return ["source": source]
            case let .captureAbandoned(filledFields):
                return ["filled_fields": "\(filledFields)"]
            case let .footprintCreated(countryCode, hasPhoto, companionsCount):
                return ["country_code": countryCode ?? "nil",
                        "has_photo": "\(hasPhoto)",
                        "companions_count": "\(companionsCount)"]
            case let .countryLit(countryCode, totalLit):
                return ["country_code": countryCode, "total_lit": "\(totalLit)"]
            case let .timelineViewed(footprintCount):
                return ["footprint_count": "\(footprintCount)"]
            case let .statsViewed(totalLit, percent):
                return ["total_lit": "\(totalLit)", "percent": "\(percent)"]
            }
        }
    }

    static func log(_ event: Event) {
        let propsDesc = event.props.map { "\($0)=\($1)" }.sorted().joined(separator: " ")
        logger.info("▶︎ \(event.name, privacy: .public) \(propsDesc, privacy: .public)")
    }
}
