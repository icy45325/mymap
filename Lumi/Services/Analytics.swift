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
        case photoImportOpened                               // 打开「从相册同步」
        case photoImportCompleted(imported: Int)             // 导入完成
        // 交换日记 v3（PRD §9）；北极星 = diary_page_revealed 与 days_to_reveal 中位数
        case diaryEntryPointShown                            // 足迹详情展示邀请卡
        case diaryCreateStarted(source: String)              // footprint / me
        case diaryCreateAbandoned(lastStep: String)
        case diaryBookCreated(pageCount: Int)
        case diaryEntrySealed(inputType: String)             // text / draw / voice
        case diaryHandoffStarted
        case diaryPageRevealed(daysToReveal: Int)            // ← 核心

        var name: String {
            switch self {
            case .appOpen:              return "app_open"
            case .captureStarted:       return "capture_started"
            case .captureAbandoned:     return "capture_abandoned"
            case .footprintCreated:     return "footprint_created"
            case .countryLit:           return "country_lit"
            case .timelineViewed:       return "timeline_viewed"
            case .statsViewed:          return "stats_viewed"
            case .photoImportOpened:    return "photo_import_opened"
            case .photoImportCompleted: return "photo_import_completed"
            case .diaryEntryPointShown: return "diary_entry_point_shown"
            case .diaryCreateStarted:   return "diary_create_started"
            case .diaryCreateAbandoned: return "diary_create_abandoned"
            case .diaryBookCreated:     return "diary_book_created"
            case .diaryEntrySealed:     return "diary_entry_sealed"
            case .diaryHandoffStarted:  return "diary_handoff_started"
            case .diaryPageRevealed:    return "diary_page_revealed"
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
            case .photoImportOpened:
                return [:]
            case let .photoImportCompleted(imported):
                return ["imported": "\(imported)"]
            case .diaryEntryPointShown, .diaryHandoffStarted:
                return [:]
            case let .diaryCreateStarted(source):
                return ["source": source]
            case let .diaryCreateAbandoned(lastStep):
                return ["last_step": lastStep]
            case let .diaryBookCreated(pageCount):
                return ["page_count": "\(pageCount)"]
            case let .diaryEntrySealed(inputType):
                return ["input_type": inputType]
            case let .diaryPageRevealed(daysToReveal):
                return ["days_to_reveal": "\(daysToReveal)"]
            }
        }
    }

    static func log(_ event: Event) {
        let propsDesc = event.props.map { "\($0)=\($1)" }.sorted().joined(separator: " ")
        logger.info("▶︎ \(event.name, privacy: .public) \(propsDesc, privacy: .public)")
    }
}
