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
