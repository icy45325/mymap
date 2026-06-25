import SwiftUI
import Foundation

// ─────────────────────────────────────────────────────────────
//  展示层国家信息（与原型 / lumi_data_model 字段对齐）。
//
//  设计：扩展而非替换。持久化的事实来源仍是 Footprint.countryCode（离线
//  point-in-polygon 解析，§5.1）。flag / 中文国名 / region 全部由 countryCode
//  **派生**，无需新增存储字段，也不引入数据同步问题。
// ─────────────────────────────────────────────────────────────

/// 地区分组（星迹时间线筛选 & 大洲统计的展示维度）。
enum Region: String, CaseIterable, Identifiable, Codable {
    case asia, europe, meast, americas, africa, oceania

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .asia:     return "亚洲"
        case .europe:   return "欧洲"
        case .meast:    return "中东"
        case .americas: return "美洲"
        case .africa:   return "非洲"
        case .oceania:  return "大洋洲"
        }
    }

    /// 环形进度 / 标记配色（原型 CONQUEST 配色）。
    var color: Color {
        switch self {
        case .asia:     return .grn
        case .europe:   return .nCyan
        case .meast:    return .nOrange
        case .americas: return .nPink
        case .africa:   return .nPurple
        case .oceania:  return .nCyan
        }
    }
}

enum CountryInfo {

    /// ISO_A2 → 国旗 emoji（区域指示符拼合，对任意合法两字母码通用）。
    static func flag(for code: String?) -> String {
        guard let raw = code, raw.count >= 2 else { return "🏳️" }
        let cc = String(raw.prefix(2)).uppercased()
        let base: UInt32 = 0x1F1E6   // 🇦
        var scalars = String.UnicodeScalarView()
        for ascii in cc.unicodeScalars {
            guard ascii.value >= 65, ascii.value <= 90,
                  let s = UnicodeScalar(base + ascii.value - 65) else { return "🏳️" }
            scalars.append(s)
        }
        return String(scalars)
    }

    /// ISO_A2 → 本地化国名（随系统语言：阿联酋 / United Arab Emirates / الإمارات）。
    static func localizedName(for code: String?) -> String? {
        guard let code else { return nil }
        return Locale.current.localizedString(forRegionCode: String(code.prefix(2)))
    }

    /// 中东国家码（这些国家在展示上归入「中东」分组，而非地理大洲）。
    static let middleEast: Set<String> =
        ["AE", "SA", "QA", "OM", "KW", "BH", "JO", "LB", "IL", "PS",
         "SY", "IQ", "IR", "YE", "TR", "EG"]

    /// Natural Earth 大洲名 + 国家码 → 展示分组 Region。
    static func region(continent: String?, countryCode: String?) -> Region? {
        if let cc = countryCode, middleEast.contains(String(cc.prefix(2))) { return .meast }
        switch continent {
        case "Asia":                          return .asia
        case "Europe":                        return .europe
        case "Africa":                        return .africa
        case "North America", "South America": return .americas
        case "Oceania":                       return .oceania
        default:                              return nil
        }
    }
}

// MARK: - Footprint 展示派生字段

extension Footprint {

    /// 国旗 emoji（由 countryCode 派生）。
    var flag: String { CountryInfo.flag(for: countryCode) }

    /// 中文国名（由 countryCode 派生；公海 / 无匹配为 nil）。
    var countryName: String? { CountryInfo.localizedName(for: countryCode) }

    /// 展示分组（由 countryCode + 大洲派生）。
    var region: Region? {
        let continent = countryCode.flatMap { Boundaries.shared.continent(forCountryCode: $0) }
        return CountryInfo.region(continent: continent, countryCode: countryCode)
    }

    /// 照片数量。
    var photoCount: Int { photoAssetIDs.count }

    /// 卡片主标题：优先城市，退回地点名。
    var title: String { cityName ?? placeName }

    /// 二级描述：城市 · 国家中文名（去重后）。
    var locationSubtitle: String {
        var parts: [String] = []
        if let city = cityName { parts.append(city) }
        if let c = countryName, c != cityName { parts.append(c) }
        return parts.joined(separator: "，")
    }

    /// 行程日期文案：单天 → 单日期；多天 → 「起 – 止」。
    func visitSpanText(_ style: Date.FormatStyle = .dateTime.year().month(.abbreviated).day()) -> String {
        let start = visitedAt.formatted(style)
        guard let end = endedAt, end > visitedAt else { return start }
        return "\(start) – \(end.formatted(style))"
    }
}
