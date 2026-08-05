import Foundation

// ─────────────────────────────────────────────────────────────
//  ContentPack —— 资源包统一抽象（v1.15 商店地基）。
//
//  设计见 docs/design/DESIGN-store.md §1–§3。要点：
//  · manifest（JSON）与远程同构：v1.15 读 Bundle，v1.2 换远程 URL 加载器，schema 不变；
//  · 现有四类邮票目录在 StorePacks.json 里有元数据镜像（legacyRaw 链接旧编码），
//    旧 raw（air|cc:|fest:|prem:）永不改写；新资源一律 `pack:<packID>/<itemID>`；
//  · 本文件只定义数据模型，不含任何权益/定价逻辑（D1–D5 决策后再接）。
// ─────────────────────────────────────────────────────────────

/// 资源包品类。
enum PackCategory: String, Codable {
    case stamp        // 邮票包
    case postmark     // 邮戳包
    case cardFront    // 明信片正面素材（插画/画框/滤镜）
    case cardBack     // 背面素材（信纸/花字/贴纸）
    case theme        // 大主题（AppTheme 扩展）
    case passport     // 护照风格
}

/// 定价档（字符串编码进 manifest："free" / "plus" / "paid:<tier>"）。
/// 具体权益语义（Plus 免费领 / 单点购买 / 折扣）随 D1/D5 决策接入，模型先行。
enum PackPricing: Codable, Equatable {
    case free
    case plus
    case paid(tier: String)

    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        switch s {
        case "free": self = .free
        case "plus": self = .plus
        default:
            if s.hasPrefix("paid:") { self = .paid(tier: String(s.dropFirst(5))) }
            else { self = .free }   // 未知档保守按 free（不至于误锁）
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .free: try c.encode("free")
        case .plus: try c.encode("plus")
        case .paid(let t): try c.encode("paid:\(t)")
        }
    }
}

/// 节日窗口（含前后缓冲的最终区间，月/日各含端点；与 `Festival.window` 同口径）。
struct PackFestivalWindow: Codable, Equatable {
    let fromMonth: Int, fromDay: Int
    let toMonth: Int, toDay: Int
}

/// 条目渲染方式：美术图（imageset / 未来远程图）或代码绘制（渲染器 id）。
struct PackItemRender: Codable, Equatable {
    let type: String            // "image" | "coded"
    var asset: String? = nil    // type=image：资源名（v1.2 起也可为远程 URL + 本地缓存名）
    var renderer: String? = nil // type=coded：渲染器 id，如 "regional:JP" / "postmark:lumi"
}

/// 资源包条目。
struct PackItem: Codable, Identifiable, Equatable {
    let id: String                              // 包内唯一；新资源 raw = pack:<packID>/<id>
    var name: [String: String] = [:]            // {"zh","en","ar"} 三语名（远程上新不依赖发版）
    let render: PackItemRender
    var legacyRaw: String? = nil                // 迁移镜像条目 → 既有编码（"cc:JP"/"prem:jp_fuji"…）
    var countryCode: String? = nil              // 条目级国家限定（如探索者包每票限本国足迹）
    var subRegionCode: String? = nil            // 子区域限定（如 AE-DU）
    var festivalWindow: PackFestivalWindow? = nil
    var regionGroup: String? = nil              // 节日地区组："meast" / "westAsia" / "cn"

    /// 按系统语言取名（zh→zh，ar→ar，其余→en；再兜底任意值）。
    var localizedName: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return name[lang] ?? name["en"] ?? name.values.first ?? id
    }
}

/// 资源包。
struct ContentPack: Codable, Identifiable, Equatable {
    let id: String                              // 全局唯一，进 raw 编码，永不复用
    let category: PackCategory
    var version: Int = 1                        // 包内容版本（远程增量更新用）
    var minAppVersion: String? = nil            // 老客户端自动隐藏看不懂的包
    var name: [String: String] = [:]
    var pricing: PackPricing = .free
    var productID: String? = nil                // pricing=paid 时 = com.lumi.pack.<id>
    var countryCodes: [String]? = nil           // 包级可用性：限定国家足迹
    var preview: String? = nil                  // 货架预览图资源名/URL
    var items: [PackItem] = []

    var localizedName: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return name[lang] ?? name["en"] ?? name.values.first ?? id
    }
}

/// manifest 顶层结构（Bundle 内置与远程同构）。
struct PackManifest: Codable {
    let schemaVersion: Int
    var packs: [ContentPack] = []
}
