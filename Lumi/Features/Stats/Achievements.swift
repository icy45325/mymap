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
    let icon: String          // SF Symbol
    let desc: String
    let ownership: String     // 全球持有率文案，如 "8%"

    var state: BadgeState
    var unlockedAt: Date?     // 仅 lit
    var progressText: String? // 仅 prog，如 "27 / 30 国"
    var progress: Double?     // 仅 prog，0...1
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
}

// MARK: - 徽章目录（点亮规则）

/// 徽章定义 + 由 LumiStats 评估出 状态 / 进度 / 解锁时间。
enum BadgeCatalog {

    static func evaluate(_ s: LumiStats) -> [Badge] {
        let c = s.countries
        let cities = s.cities
        let continentsCovered = s.conquest.filter { $0.lit > 0 }.count

        func milestone(_ id: String, _ name: String, _ rarity: Rarity, _ cat: BadgeCategory,
                       _ icon: String, _ desc: String, _ pct: String,
                       target: Int, current: Int, unit: String) -> Badge {
            if current >= target {
                return Badge(id: id, name: name, rarity: rarity, category: cat, icon: icon,
                             desc: desc, ownership: pct, state: .lit,
                             unlockedAt: s.unlockDate(atCountryCount: min(target, c)))
            }
            return Badge(id: id, name: name, rarity: rarity, category: cat, icon: icon,
                         desc: desc, ownership: pct, state: .prog,
                         progressText: "\(current) / \(target) \(unit)",
                         progress: Double(current) / Double(target))
        }

        func flag(_ id: String, _ name: String, _ rarity: Rarity, _ cat: BadgeCategory,
                  _ icon: String, _ desc: String, _ pct: String,
                  unlocked: Bool, at: Date?) -> Badge {
            Badge(id: id, name: name, rarity: rarity, category: cat, icon: icon,
                  desc: desc, ownership: pct, state: unlocked ? .lit : .locked,
                  unlockedAt: unlocked ? at : nil)
        }

        let list: [Badge] = [
            flag("first", "初次点亮", .common, .explore, "mappin",
                 "点亮你的第一个足迹。旅程由此开始。", "88%",
                 unlocked: c >= 1, at: s.unlockDate(atCountryCount: 1)),

            milestone("five", "环游五国", .rare, .milestone, "globe.asia.australia.fill",
                      "点亮 5 个不同国家。", "31%", target: 5, current: c, unit: "国"),

            milestone("world", "环球旅人", .epic, .milestone, "safari.fill",
                      "点亮 30 个国家即可解锁这枚史诗徽章。", "5%", target: 30, current: c, unit: "国"),

            flag("desert", "沙漠拓荒者", .epic, .milestone, "sun.max.fill",
                 "首次点亮中东地区，开启一整片新大陆。", "8%",
                 unlocked: s.litRegion(.meast), at: s.footprints.first { $0.region == .meast }?.visitedAt),

            flag("asiastar", "亚洲之星", .epic, .continent, "star.fill",
                 "在亚洲点亮足迹。", "11%",
                 unlocked: s.litRegion(.asia), at: s.footprints.first { $0.region == .asia }?.visitedAt),

            flag("europe", "欧陆漫游", .rare, .continent, "calendar",
                 "在欧洲点亮足迹。", "19%",
                 unlocked: s.litRegion(.europe), at: s.footprints.first { $0.region == .europe }?.visitedAt),

            milestone("cities", "百城灯火", .common, .milestone, "building.2.fill",
                      "累计点亮 100 座城市。", "4%", target: 100, current: cities, unit: "城"),

            milestone("continents", "七洲集齐", .legendary, .explore, "globe",
                      "集齐各大洲的足迹。终极荣耀。", "1%",
                      target: 5, current: continentsCovered, unit: "洲"),

            flag("africa", "非洲先锋", .rare, .continent, "leaf.fill",
                 "点亮非洲首个国家。", "14%",
                 unlocked: s.litRegion(.africa), at: s.footprints.first { $0.region == .africa }?.visitedAt),

            flag("americas", "美洲征服", .epic, .continent, "globe.americas.fill",
                 "点亮美洲首个国家。", "3%",
                 unlocked: s.litRegion(.americas), at: s.footprints.first { $0.region == .americas }?.visitedAt),
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
