import SwiftUI

/// 典藏邮票（**Plus 专属**）：分国家（部分再绑城市/子区域）的精美邮票美术。
/// 使用规则与地区票一致——**仅限匹配足迹**的明信片；AE 四枚按酋长国绑定
/// （迪拜足迹只见哈利法塔票）。非 Plus 用户在选择器里可见前 2 枚（带锁）作付费入口。
/// 编码 `"prem:<id>"` 随口令传达；收件人无论是否 Plus 都正常显示（卡面是发送方权益）。
struct PremiumStamp: Identifiable, Equatable, Hashable {
    let id: String              // "cn_skyline" …
    let code: String            // 国家码
    let subRegion: String?      // 子区域绑定（AE 酋长国码 "AE-AZ"/"AE-DU"；nil=全国可用）
    let imageName: String       // Assets: premium_<id>
    let nameKey: LocalizedStringKey

    // LocalizedStringKey 不是 Hashable，手动按 id 实现（目录内 id 唯一）。
    static func == (lhs: PremiumStamp, rhs: PremiumStamp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var raw: String { "prem:\(id)" }

    static let all: [PremiumStamp] = [
        // 中国
        PremiumStamp(id: "cn_skyline",    code: "CN", subRegion: nil, imageName: "premium_cn_skyline",    nameKey: "上海天际线"),
        PremiumStamp(id: "cn_dragon",     code: "CN", subRegion: nil, imageName: "premium_cn_dragon",     nameKey: "龙跃长城"),
        PremiumStamp(id: "cn_terracotta", code: "CN", subRegion: nil, imageName: "premium_cn_terracotta", nameKey: "长城·兵马俑"),
        // 美国
        PremiumStamp(id: "us_modern",     code: "US", subRegion: nil, imageName: "premium_us_modern",     nameKey: "摩天都市"),
        PremiumStamp(id: "us_skylines",   code: "US", subRegion: nil, imageName: "premium_us_skylines",   nameKey: "永恒天际线"),
        PremiumStamp(id: "us_western",    code: "US", subRegion: nil, imageName: "premium_us_western",    nameKey: "西部风情"),
        // 日本
        PremiumStamp(id: "jp_fuji",       code: "JP", subRegion: nil, imageName: "premium_jp_fuji",       nameKey: "富士花信"),
        PremiumStamp(id: "jp_ukiyoe",     code: "JP", subRegion: nil, imageName: "premium_jp_ukiyoe",     nameKey: "浮世佳人"),
        PremiumStamp(id: "jp_wave",       code: "JP", subRegion: nil, imageName: "premium_jp_wave",       nameKey: "富士浪涛"),
        PremiumStamp(id: "jp_fisher",     code: "JP", subRegion: nil, imageName: "premium_jp_fisher",     nameKey: "江户渔人"),
        // 阿联酋（绑酋长国：阿布扎比 AE-AZ / 迪拜 AE-DU）
        PremiumStamp(id: "ae_arc",        code: "AE", subRegion: "AE-AZ", imageName: "premium_ae_arc",    nameKey: "金弧之城"),
        PremiumStamp(id: "ae_mosque",     code: "AE", subRegion: "AE-AZ", imageName: "premium_ae_mosque", nameKey: "大清真寺"),
        PremiumStamp(id: "ae_louvre",     code: "AE", subRegion: "AE-AZ", imageName: "premium_ae_louvre", nameKey: "艺术之岛"),
        PremiumStamp(id: "ae_burj",       code: "AE", subRegion: "AE-DU", imageName: "premium_ae_burj",   nameKey: "哈利法塔"),
        // 西班牙（2026-07-08 批）
        PremiumStamp(id: "es_sagrada",    code: "ES", subRegion: nil, imageName: "premium_es_sagrada",  nameKey: "圣家堂"),
        PremiumStamp(id: "es_toro",       code: "ES", subRegion: nil, imageName: "premium_es_toro",     nameKey: "斗牛士"),
        PremiumStamp(id: "es_flamenco",   code: "ES", subRegion: nil, imageName: "premium_es_flamenco", nameKey: "弗拉明戈"),
        PremiumStamp(id: "es_quixote",    code: "ES", subRegion: nil, imageName: "premium_es_quixote",  nameKey: "堂吉诃德"),
    ]

    static func byID(_ id: String) -> PremiumStamp? { all.first { $0.id == id } }

    /// 匹配足迹：国家码一致，且（票不绑子区域 || 足迹无子区域码（旧数据兜底放宽） || 两者相等）。
    static func matching(countryCode: String?, subRegionCode: String?) -> [PremiumStamp] {
        guard let code = countryCode?.uppercased() else { return [] }
        return all.filter { s in
            guard s.code == code else { return false }
            guard let bind = s.subRegion, let sub = subRegionCode, !sub.isEmpty else { return true }
            return bind == sub
        }
    }

    /// 子区域的城市名（图鉴脚注用；本地化键）。
    var cityKey: LocalizedStringKey? {
        switch subRegion {
        case "AE-AZ": return "阿布扎比"
        case "AE-DU": return "迪拜"
        default:      return nil
        }
    }
}
