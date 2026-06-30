import SwiftUI

/// 节日邮戳：明信片**寄出/分享日期**落在某节日窗口（前后 2 天）内、且足迹**所在地区**匹配时，
/// 邮局（Lumi）盖的章换成对应节日主题章。仅收件人查看时展示（见 PostcardBackPanel.showPostmark）。
///
/// 地区归属：中东 → 伊斯兰/阿联酋节日；中国 → 中秋/国庆；欧美 + 亚洲（含中、新、日韩等，不含中东）→ 感恩节/圣诞。
/// 日期按公历「月-日」匹配（与年份无关，逐年复用）；农历节日按用户给定公历近似，后续可接农历换算。
enum Festival: String, CaseIterable, Identifiable {
    case prophetBirthday      // 先知穆罕默德诞辰：8/25（±2）
    case uaeNationalDay       // 阿联酋国庆：12/2–12/3（±2）
    case thanksgiving         // 感恩节：11/26（±2）
    case christmas            // 圣诞节：12/25（±2）
    case midAutumn            // 中秋：9/25–9/27（±2）
    case chinaNationalDay     // 中国国庆（黄金周）：10/1–10/7（±2）

    var id: String { rawValue }

    /// 章上短字（直接印在图上，不进本地化目录）。
    var caption: String {
        switch self {
        case .prophetBirthday: return "MAWLID"
        case .uaeNationalDay:   return "UAE"
        case .thanksgiving:     return "THANKS"
        case .christmas:        return "XMAS"
        case .midAutumn:        return "中秋"
        case .chinaNationalDay: return "国庆"
        }
    }
    /// 章中心图标（SF Symbol）。
    var motif: String {
        switch self {
        case .prophetBirthday: return "moon.stars.fill"
        case .uaeNationalDay:   return "flag.fill"
        case .thanksgiving:     return "leaf.fill"
        case .christmas:        return "snowflake"
        case .midAutumn:        return "moon.fill"
        case .chinaNationalDay: return "star.fill"
        }
    }
    /// 主色（环 + 图标 + 字）。
    var ink: Color {
        switch self {
        case .prophetBirthday: return Color(hex: 0x1F7A4D)
        case .uaeNationalDay:   return Color(hex: 0xCE1126)
        case .thanksgiving:     return Color(hex: 0xB5651D)
        case .christmas:        return Color(hex: 0xC8102E)
        case .midAutumn:        return Color(hex: 0xB8860B)
        case .chinaNationalDay: return Color(hex: 0xDE2910)
        }
    }
    /// 底色（淡淡填充）。
    var accent: Color {
        switch self {
        case .prophetBirthday: return Color(hex: 0xC9A24B)
        case .uaeNationalDay:   return Color(hex: 0x009639)
        case .thanksgiving:     return Color(hex: 0xE8A24B)
        case .christmas:        return Color(hex: 0x146B3A)
        case .midAutumn:        return Color(hex: 0xE8B04B)
        case .chinaNationalDay: return Color(hex: 0xFFDE00)
        }
    }
    /// 中文名（文档 / 预览用，不入码上）。
    var title: String {
        switch self {
        case .prophetBirthday: return "先知诞辰"
        case .uaeNationalDay:   return "阿联酋国庆"
        case .thanksgiving:     return "感恩节"
        case .christmas:        return "圣诞节"
        case .midAutumn:        return "中秋"
        case .chinaNationalDay: return "中国国庆"
        }
    }

    /// 节日窗口（含两端，已并入前后 2 天）。以 (月,日) 表示。
    private var window: (from: (Int, Int), to: (Int, Int)) {
        switch self {
        case .prophetBirthday: return ((8, 23), (8, 27))   // 8/25 ±2
        case .uaeNationalDay:   return ((11, 30), (12, 5))  // 12/2–12/3 ±2
        case .thanksgiving:     return ((11, 24), (11, 28)) // 11/26 ±2
        case .christmas:        return ((12, 23), (12, 27)) // 12/25 ±2
        case .midAutumn:        return ((9, 23), (9, 29))   // 9/25–9/27 ±2
        case .chinaNationalDay: return ((9, 29), (10, 9))   // 10/1–10/7 ±2
        }
    }

    private func contains(month: Int, day: Int) -> Bool {
        let (f, t) = window
        let v = month * 100 + day, lo = f.0 * 100 + f.1, hi = t.0 * 100 + t.1
        return v >= lo && v <= hi   // 所有窗口都不跨年，直接比较
    }

    // MARK: - 匹配

    /// 中东（伊斯兰 / 阿拉伯）地区国家码。
    private static let middleEast: Set<String> = [
        "AE", "SA", "QA", "KW", "BH", "OM", "JO", "LB", "IQ", "YE", "SY", "PS", "IR",
    ]

    private static func isMiddleEast(_ code: String) -> Bool { middleEast.contains(code) }

    /// 欧美 + 亚洲（不含中东）：按大洲归属判定。
    private static func isWesternOrAsia(_ code: String) -> Bool {
        guard !isMiddleEast(code) else { return false }
        guard let c = Boundaries.shared.continent(forCountryCode: code) else { return false }
        return ["Europe", "North America", "South America", "Asia"].contains(c)
    }

    /// 按足迹所在国家码 + 寄出/分享日期，匹配应盖的节日章；无匹配返回 nil（用通用 Lumi 邮戳）。
    static func match(countryCode: String?, date: Date) -> Festival? {
        guard let code = countryCode?.uppercased() else { return nil }
        let comps = Calendar.current.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return nil }

        if isMiddleEast(code) {                         // 中东：仅伊斯兰 / 阿联酋节日
            if Festival.prophetBirthday.contains(month: m, day: d) { return .prophetBirthday }
            if Festival.uaeNationalDay.contains(month: m, day: d) { return .uaeNationalDay }
            return nil
        }
        if code == "CN" {                               // 中国：中秋 / 国庆优先
            if Festival.midAutumn.contains(month: m, day: d) { return .midAutumn }
            if Festival.chinaNationalDay.contains(month: m, day: d) { return .chinaNationalDay }
            // 落空则继续走亚洲组（圣诞 / 感恩节）
        }
        if isWesternOrAsia(code) {                      // 欧美 + 亚洲（含中、新、日韩等）
            if Festival.thanksgiving.contains(month: m, day: d) { return .thanksgiving }
            if Festival.christmas.contains(month: m, day: d) { return .christmas }
        }
        return nil
    }
}

/// 节日主题邮戳（圆形盖章风），替换明信片背面通用「LUMI」邮戳。
struct FestivalSeal: View {
    let festival: Festival
    var year: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: festival.motif).font(.system(size: 9))
            Text(verbatim: festival.caption).font(.system(size: 3.6, weight: .bold)).tracking(0.3)
                .lineLimit(1).minimumScaleFactor(0.5)
            if !year.isEmpty {
                Text(verbatim: year).font(.system(size: 3.2, design: .monospaced))
            }
        }
        .foregroundStyle(festival.ink)
        .frame(width: 34, height: 34)
        .background(Circle().fill(festival.accent.opacity(0.16)))
        .overlay(Circle().stroke(festival.ink, lineWidth: 1.2))
        .overlay(Circle().stroke(festival.ink.opacity(0.4), lineWidth: 0.5).padding(2.5))
        .rotationEffect(.degrees(-8))
    }
}
