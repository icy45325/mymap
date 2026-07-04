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

    /// 节日章贴图资源名（霓虹邮票线稿，Assets.xcassets）。
    var imageName: String {
        switch self {
        case .prophetBirthday: return "festival_prophet"
        case .uaeNationalDay:   return "festival_uae"
        case .thanksgiving:     return "festival_thanksgiving"
        case .christmas:        return "festival_christmas"
        case .midAutumn:        return "festival_midautumn"
        case .chinaNationalDay: return "festival_china"
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

    /// 本地化展示名（图鉴等 UI 用）。
    var titleKey: LocalizedStringKey {
        switch self {
        case .prophetBirthday: return "先知诞辰"
        case .uaeNationalDay:   return "阿联酋国庆"
        case .thanksgiving:     return "感恩节"
        case .christmas:        return "圣诞节"
        case .midAutumn:        return "中秋"
        case .chinaNationalDay: return "中国国庆"
        }
    }
    /// 收集窗口的展示文本（含前后 2 天，如 "8.23 – 8.27"）。
    var windowText: String {
        let (f, t) = window
        return "\(f.0).\(f.1) – \(t.0).\(t.1)"
    }
    /// 该章适用地区的本地化说明。
    var regionKey: LocalizedStringKey {
        switch self {
        case .prophetBirthday, .uaeNationalDay: return "中东足迹"
        case .thanksgiving, .christmas:          return "欧美与亚洲足迹"
        case .midAutumn, .chinaNationalDay:      return "中国足迹"
        }
    }

    /// 节日窗口（含两端，已并入前后 5 天）。以 (月,日) 表示。
    private var window: (from: (Int, Int), to: (Int, Int)) {
        switch self {
        case .prophetBirthday: return ((8, 20), (8, 30))    // 8/25 ±5
        case .uaeNationalDay:   return ((11, 27), (12, 8))   // 12/2–12/3 ±5
        case .thanksgiving:     return ((11, 21), (12, 1))   // 11/26 ±5
        case .christmas:        return ((12, 20), (12, 30))  // 12/25 ±5
        case .midAutumn:        return ((9, 20), (10, 2))    // 9/25–9/27 ±5
        case .chinaNationalDay: return ((9, 26), (10, 12))   // 10/1–10/7 ±5
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

    /// 某国家码可用的节日集合（地区限定：中东 / 中国额外 / 欧美+亚洲）。
    private static func regionFestivals(_ code: String) -> [Festival] {
        if isMiddleEast(code) { return [.prophetBirthday, .uaeNationalDay] }
        var list: [Festival] = []
        if code == "CN" { list += [.midAutumn, .chinaNationalDay] }
        if isWesternOrAsia(code) { list += [.thanksgiving, .christmas] }
        return list
    }

    /// **寄卡时**可选的节日章：足迹所在地区匹配 + 给定日期落在节日窗口（前后 5 天）内。
    static func eligible(countryCode: String?, on date: Date) -> [Festival] {
        guard let code = countryCode?.uppercased() else { return [] }
        let comps = Calendar.current.dateComponents([.month, .day], from: date)
        guard let m = comps.month, let d = comps.day else { return [] }
        return regionFestivals(code).filter { $0.contains(month: m, day: d) }
    }

    /// 按足迹所在国家码 + 日期匹配单个节日（旧收到卡的兼容判定用）。
    static func match(countryCode: String?, date: Date) -> Festival? {
        eligible(countryCode: countryCode, on: date).first
    }
}

/// 节日主题邮票（霓虹线稿贴图），命中节日窗口时盖在收到的明信片邮票位。
struct FestivalSeal: View {
    let festival: Festival

    var body: some View {
        Image(festival.imageName)
            .resizable().scaledToFit()
            .rotationEffect(.degrees(-6))
            .shadow(color: Color(hex: 0x9B5DE5).opacity(0.5), radius: 4)
    }
}
