import SwiftUI
import Foundation

// ─────────────────────────────────────────────────────────────
//  成就 / 统计领域模型（与 lumi_data_model 字段对齐）。
//
//  全部由 [Footprint] **派生**——徽章 / 大洲征服 / 概览数字不持久化，
//  始终与真实点亮数据一致（扩展现有模型，不另立数据源）。
// ─────────────────────────────────────────────────────────────

// MARK: - 枚举

enum Rarity: String, CaseIterable {
    case common, rare, epic, legendary

    var tierName: String {
        switch self {
        case .common: return "普通"; case .rare: return "稀有"
        case .epic:   return "史诗"; case .legendary: return "传说"
        }
    }
    var color: Color {
        switch self {
        case .common: return Color(hex: 0x9A9AB0)
        case .rare:   return .nCyan
        case .epic:   return .nPink
        case .legendary: return .nOrange
        }
    }
    /// 六边形填充渐变（原型 --fillg）。
    var fill: LinearGradient {
        let c: [Color]
        switch self {
        case .common:    c = [Color(hex: 0x6F6F96), Color(hex: 0x46465F)]
        case .rare:      c = [.nCyan, Color(hex: 0x7A6FD0)]
        case .epic:      c = [.nPink, .nPurple]
        case .legendary: c = [Color(hex: 0xFFC76B), Color(hex: 0xFF7A4D)]
        }
        return LinearGradient(colors: c, startPoint: .top, endPoint: .bottom)
    }
    var rank: Int {
        switch self {
        case .common: return 0; case .rare: return 1
        case .epic: return 2; case .legendary: return 3
        }
    }
}

enum BadgeCategory: String, CaseIterable {
    case explore, continent, milestone, streak

    var displayName: String {
        switch self {
        case .explore:   return "探索"
        case .continent: return "大洲"
        case .milestone: return "里程碑"
        case .streak:    return "连续"
        }
    }
}

enum BadgeState { case lit, prog, locked }

// MARK: - 徽章（值类型，派生）

struct Badge: Identifiable {
    let id: String
    let name: String
    let rarity: Rarity
    let category: BadgeCategory
    let icon: String          // SF Symbol（无插画时的兜底图标）
    let desc: String
    let ownership: String     // 全球持有率文案，如 "8%"
    var tint: Color? = nil    // 逐徽章霓虹色（覆盖 rarity 默认色）
    var imageName: String? = nil  // 有则渲染插画徽章（asset catalog），否则用 SF Symbol

    var state: BadgeState
    var unlockedAt: Date?     // 仅 lit
    var progressText: String? // 仅 prog，如 "27 / 30 国"
    var progress: Double?     // 仅 prog，0...1

    /// 渲染用主色：优先逐徽章 tint，回退稀有度色。
    var color: Color { tint ?? rarity.color }
}

// MARK: - 大洲征服 / 概览

struct ConquestEntry: Identifiable {
    var id: String { region.rawValue }
    let region: Region
    let lit: Int
    let total: Int
    var percent: Int { total > 0 ? Int((Double(lit) / Double(total) * 100).rounded()) : 0 }
}

/// 地图 / 详情用的精彩瞬间（有照片的足迹）。
struct Highlight: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let assetID: String?
}

// MARK: - 统计聚合（单一计算入口）

/// 把 [Footprint] 聚合成各页所需的派生数据，保证 地图 / 星迹 / 成就 / 我 口径一致。
struct LumiStats {

    let footprints: [Footprint]

    // —— 基础口径（§5.1 distinct）——
    var litCountryCodes: Set<String> { Set(footprints.compactMap { $0.countryCode }) }
    var countries: Int { litCountryCodes.count }
    var cities: Int { Set(footprints.compactMap { $0.cityName }).count }

    var worldTotal: Int { max(Boundaries.shared.totalCountryCount, 1) }
    var worldPercent: Double { Double(countries) / Double(worldTotal) * 100 }

    /// 等级：每 4 国升一级（轻量游戏化，可调）。
    var level: Int { countries / 4 + 1 }
    var levelProgress: Double { Double(countries % 4) / 4 }
    var toNextLevel: Int { 4 - (countries % 4) }

    // —— 大洲征服（用地理大洲做分母，口径稳定）——
    private static let conquestRegions: [(Region, String)] = [
        (.asia, "Asia"), (.europe, "Europe"), (.americas, "North America"),
        (.africa, "Africa"), (.oceania, "Oceania"),
    ]

    var conquest: [ConquestEntry] {
        Self.conquestRegions.compactMap { region, continentA in
            let continents: [String] = region == .americas
                ? ["North America", "South America"] : [continentA]
            let total = continents.reduce(0) { $0 + (Boundaries.shared.countriesPerContinent[$1] ?? 0) }
            guard total > 0 else { return nil }
            let lit = litCountryCodes.filter { code in
                guard let c = Boundaries.shared.continent(forCountryCode: code) else { return false }
                return continents.contains(c)
            }.count
            return ConquestEntry(region: region, lit: lit, total: total)
        }
    }

    // —— 精彩瞬间（最近的、带照片的足迹）——
    var highlights: [Highlight] {
        footprints
            .filter { !$0.photoAssetIDs.isEmpty }
            .prefix(8)
            .map { Highlight(id: $0.id, title: $0.title,
                             subtitle: $0.countryName ?? $0.placeName,
                             assetID: $0.photoAssetIDs.first) }
    }

    // —— 徽章 ——
    var badgeBoard: BadgeBoard { BadgeBoard(badges: BadgeCatalog.evaluate(self)) }

    /// 解锁日期：以触发该里程碑的足迹（按时间排序的第 n 个）的到访日作近似。
    func unlockDate(atCountryCount n: Int) -> Date? {
        let ordered = footprints
            .sorted { $0.visitedAt < $1.visitedAt }
        var seen = Set<String>()
        for fp in ordered {
            if let code = fp.countryCode, seen.insert(code).inserted, seen.count == n {
                return fp.visitedAt
            }
        }
        return nil
    }

    func litRegion(_ region: Region) -> Bool {
        footprints.contains { $0.region == region }
    }

    // —— 新检测（参考徽章表） ——

    /// 南极洲：落点在南纬 60° 以下即算（坐标判定，无需边界数据）。
    var litAntarctica: Bool { footprints.contains { $0.latitude < -60 } }
    var antarcticaVisits: Int { footprints.filter { $0.latitude < -60 }.count }

    /// 跳岛狂人：点亮的不同「岛屿国家/地区」数。
    var islandCountryCount: Int { litCountryCodes.intersection(Self.islandCountries).count }

    /// 丛林探索者：是否点亮过雨林国家。
    var litRainforest: Bool { !litCountryCodes.isDisjoint(with: Self.rainforestCountries) }
    static func isRainforest(_ code: String) -> Bool { rainforestCountries.contains(code) }

    /// 制霸七大洲：覆盖的地理大洲数（含南极洲，共 7）。
    var continentsCovered: Int {
        var set = Set<String>()
        for code in litCountryCodes {
            if let cont = Boundaries.shared.continent(forCountryCode: code) { set.insert(cont) }
        }
        if litAntarctica { set.insert("Antarctica") }
        return set.intersection(Self.sevenContinents).count
    }

    private static let sevenContinents: Set<String> = [
        "Asia", "Europe", "Africa", "North America", "South America", "Oceania", "Antarctica",
    ]
    /// 主要岛屿国家/地区（ISO_A2，精选可扩充）。
    private static let islandCountries: Set<String> = [
        "MV", "ID", "PH", "JP", "GB", "IS", "MT", "MU", "LK", "CY", "NZ", "FJ",
        "SC", "BS", "BB", "MG", "JM", "DO", "CU", "IE", "TW", "MS", "WS", "TO", "PW",
    ]
    /// 雨林覆盖率高的国家（ISO_A2，精选可扩充）。
    private static let rainforestCountries: Set<String> = [
        "BR", "ID", "CO", "PE", "CD", "MY", "VE", "BO", "EC", "CR", "PA", "GA", "CM", "CG", "GH",
    ]
}

// MARK: - 徽章目录（点亮规则）

/// 徽章定义 + 由 LumiStats 评估出 状态 / 进度 / 解锁时间。
enum BadgeCatalog {

    static func evaluate(_ s: LumiStats) -> [Badge] {
        let c = s.countries
        let cities = s.cities
        let continents = s.continentsCovered

        func milestone(_ id: String, _ name: String, _ rarity: Rarity, _ cat: BadgeCategory,
                       _ icon: String, _ desc: String, _ pct: String, _ tint: Color,
                       target: Int, current: Int, unit: String, image: String? = nil) -> Badge {
            if current >= target {
                return Badge(id: id, name: name, rarity: rarity, category: cat, icon: icon,
                             desc: desc, ownership: pct, tint: tint, imageName: image, state: .lit,
                             unlockedAt: s.unlockDate(atCountryCount: min(target, c)))
            }
            return Badge(id: id, name: name, rarity: rarity, category: cat, icon: icon,
                         desc: desc, ownership: pct, tint: tint, imageName: image, state: .prog,
                         progressText: "\(current) / \(target) \(unit.localized)",
                         progress: Double(current) / Double(target))
        }

        func flag(_ id: String, _ name: String, _ rarity: Rarity, _ cat: BadgeCategory,
                  _ icon: String, _ desc: String, _ pct: String, _ tint: Color,
                  unlocked: Bool, at: Date?, image: String? = nil) -> Badge {
            Badge(id: id, name: name, rarity: rarity, category: cat, icon: icon,
                  desc: desc, ownership: pct, tint: tint, imageName: image,
                  state: unlocked ? .lit : .locked,
                  unlockedAt: unlocked ? at : nil)
        }

        func firstVisit(_ predicate: (Footprint) -> Bool) -> Date? {
            s.footprints.filter(predicate).min { $0.visitedAt < $1.visitedAt }?.visitedAt
        }

        let list: [Badge] = [
            flag("first", "初次点亮", .common, .explore, "mappin",
                 "点亮你的第一个足迹。旅程由此开始。", "88%", Color(hex: 0x9999FF),
                 unlocked: c >= 1, at: s.unlockDate(atCountryCount: 1), image: "badge_first"),

            milestone("five", "五国纵横", .rare, .milestone, "globe.asia.australia.fill",
                      "全球累计点亮 5 个不同国家。", "31%", Color(hex: 0x4A90E2),
                      target: 5, current: c, unit: "国", image: "badge_five"),

            milestone("world", "环球旅行家", .epic, .milestone, "safari.fill",
                      "点亮 30 个国家解锁这枚史诗徽章。", "5%", Color(hex: 0xFF0055),
                      target: 30, current: c, unit: "国", image: "badge_world"),

            flag("desert", "大漠先锋", .epic, .milestone, "sun.max.fill",
                 "在干旱 / 沙漠气候城市（如阿布扎比、迪拜）打卡。", "8%", Color(hex: 0xE91E63),
                 unlocked: s.litRegion(.meast), at: firstVisit { $0.region == .meast },
                 image: "badge_desert"),

            milestone("cities", "百城斩", .common, .milestone, "building.2.fill",
                      "全球累计打卡的不同城市总数达 100。", "4%", Color(hex: 0x607D8B),
                      target: 100, current: cities, unit: "城", image: "badge_cities"),

            milestone("continents", "制霸七大洲", .legendary, .explore, "globe",
                      "全球 7 个大洲均至少含 1 个点亮足迹。", "1%", Color(hex: 0xFF9900),
                      target: 7, current: continents, unit: "洲", image: "badge_continents"),

            flag("asiastar", "亚洲之星", .epic, .continent, "star.fill",
                 "在亚洲点亮足迹。", "11%", Color(hex: 0xFF3366),
                 unlocked: s.litRegion(.asia), at: firstVisit { $0.region == .asia },
                 image: "badge_asia"),

            flag("europe", "欧洲漫游者", .rare, .continent, "calendar",
                 "在欧洲点亮足迹。", "19%", Color(hex: 0x33CCFF),
                 unlocked: s.litRegion(.europe), at: firstVisit { $0.region == .europe },
                 image: "badge_europe"),

            flag("africa", "非洲开拓者", .rare, .continent, "tree.fill",
                 "在非洲点亮首个国家。", "14%", Color(hex: 0x00CC66),
                 unlocked: s.litRegion(.africa), at: firstVisit { $0.region == .africa },
                 image: "badge_africa"),

            flag("americas", "美洲征服者", .epic, .continent, "mountain.2.fill",
                 "在北美 / 南美点亮首个国家。", "3%", Color(hex: 0xFF6600),
                 unlocked: s.litRegion(.americas), at: firstVisit { $0.region == .americas },
                 image: "badge_americas"),

            flag("oceania", "大洋洲游牧民", .epic, .continent, "figure.surfing",
                 "在大洋洲点亮首个国家。", "6%", Color(hex: 0x00F2FE),
                 unlocked: s.litRegion(.oceania), at: firstVisit { $0.region == .oceania },
                 image: "badge_oceania"),

            flag("antarctica", "南极洲探险家", .legendary, .continent, "snowflake",
                 "在南极洲（南纬 60° 以下）成功打卡。", "0.5%", Color(hex: 0xE0F7FA),
                 unlocked: s.litAntarctica, at: firstVisit { $0.latitude < -60 },
                 image: "badge_antarctica"),

            flag("antarcticaPro", "极寒先锋", .legendary, .continent, "snowflake.circle.fill",
                 "多次造访南极极寒点（≥ 2 次）。", "0.2%", Color(hex: 0xB3E5FC),
                 unlocked: s.antarcticaVisits >= 2, at: firstVisit { $0.latitude < -60 },
                 image: "badge_antarcticaPro"),

            flag("jungle", "丛林探索者", .epic, .continent, "leaf.fill",
                 "在雨林覆盖率极高国家（如巴西、印尼）打卡。", "2%", Color(hex: 0x2E7D32),
                 unlocked: s.litRainforest,
                 at: firstVisit { $0.countryCode.map { LumiStats.isRainforest($0) } ?? false },
                 image: "badge_jungle"),

            flag("island", "跳岛狂人", .rare, .streak, "sailboat.fill",
                 "点亮 3 个不相连的岛屿国家 / 地区。", "7%", Color(hex: 0x00BFA5),
                 unlocked: s.islandCountryCount >= 3, at: nil, image: "badge_island"),
        ]

        return list
    }
}

/// 徽章面板：在徽章列表之上计算「置顶展示」「即将解锁」等展示位。
struct BadgeBoard {
    let badges: [Badge]

    var total: Int { badges.count }
    var unlockedCount: Int { badges.filter { $0.state == .lit }.count }

    /// 置顶展示：稀有度最高的已解锁徽章。
    var featured: Badge? {
        badges.filter { $0.state == .lit }
            .max { $0.rarity.rank < $1.rarity.rank }
    }

    /// 即将解锁：进度最高的进行中徽章。
    var nextUp: Badge? {
        badges.filter { $0.state == .prog }
            .max { ($0.progress ?? 0) < ($1.progress ?? 0) }
    }

    /// 解锁历程：已点亮徽章按解锁时间升序。
    var unlockHistory: [Badge] {
        badges.filter { $0.state == .lit }
            .sorted { ($0.unlockedAt ?? .distantPast) < ($1.unlockedAt ?? .distantPast) }
    }
}
