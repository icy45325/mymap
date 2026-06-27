import Foundation

/// 目的地小指南：心愿卡上展示「推荐地点 / 最佳季节 / 游玩简述」。
/// v0 为**精选静态内容**（中文为主，后续可译/扩充）；按国家码取。
struct DestinationGuide {
    let spots: String      // 推荐地点
    let season: String     // 最佳季节
    let blurb: String      // 一句游玩简述

    static func of(_ code: String?) -> DestinationGuide? {
        guard let cc = code?.uppercased() else { return nil }
        return table[cc]
    }

    private static let table: [String: DestinationGuide] = [
        "JP": .init(spots: "东京 · 京都 · 富士山 · 大阪", season: "春赏樱 / 秋赏枫", blurb: "古今交融、四季分明，美食与温泉的国度。"),
        "FR": .init(spots: "巴黎 · 普罗旺斯 · 尼斯", season: "5–9 月", blurb: "浪漫之都与薰衣草田，艺术与美食之乡。"),
        "IT": .init(spots: "罗马 · 威尼斯 · 佛罗伦萨", season: "4–6 / 9–10 月", blurb: "古罗马遗迹、文艺复兴与地中海风情。"),
        "ES": .init(spots: "巴塞罗那 · 马德里 · 塞维利亚", season: "3–5 / 9–11 月", blurb: "高迪建筑、弗拉明戈与阳光海岸。"),
        "GB": .init(spots: "伦敦 · 爱丁堡 · 湖区", season: "5–9 月", blurb: "古典与现代交织，城堡与博物馆。"),
        "US": .init(spots: "纽约 · 旧金山 · 国家公园", season: "全年（各地不同）", blurb: "从都市天际线到壮阔自然。"),
        "TH": .init(spots: "曼谷 · 清迈 · 普吉", season: "11–2 月（凉季）", blurb: "寺庙、海岛与街头美食的微笑国度。"),
        "SG": .init(spots: "滨海湾 · 圣淘沙 · 乌节路", season: "全年", blurb: "花园城市，多元美食与现代地标。"),
        "KR": .init(spots: "首尔 · 釜山 · 济州", season: "4–6 / 9–11 月", blurb: "潮流与传统并存，美食与综艺之地。"),
        "VN": .init(spots: "河内 · 下龙湾 · 会安", season: "11–4 月", blurb: "山海之间的烟火气与法式风情。"),
        "ID": .init(spots: "巴厘岛 · 日惹 · 科莫多", season: "5–9 月（旱季）", blurb: "海岛、火山与古庙的热带天堂。"),
        "AE": .init(spots: "迪拜 · 阿布扎比", season: "11–3 月", blurb: "沙漠与摩天楼，奢华与传统并存。"),
        "TR": .init(spots: "伊斯坦布尔 · 卡帕多奇亚", season: "4–5 / 9–11 月", blurb: "横跨欧亚，热气球与千年古城。"),
        "EG": .init(spots: "开罗 · 卢克索 · 红海", season: "10–4 月", blurb: "金字塔与尼罗河的千年文明。"),
        "MA": .init(spots: "马拉喀什 · 非斯 · 撒哈拉", season: "3–5 / 9–11 月", blurb: "迷宫老城与沙漠星空。"),
        "ZA": .init(spots: "开普敦 · 克鲁格", season: "10–4 月", blurb: "桌山、好望角与野生动物。"),
        "AU": .init(spots: "悉尼 · 墨尔本 · 大堡礁", season: "9–11 / 3–5 月", blurb: "海滩、珊瑚礁与辽阔内陆。"),
        "NZ": .init(spots: "皇后镇 · 南岛", season: "12–2 月", blurb: "雪山湖泊与极限运动的纯净之地。"),
        "CA": .init(spots: "温哥华 · 班夫 · 多伦多", season: "6–9 月", blurb: "落基山脉、湖泊与枫叶国度。"),
        "MX": .init(spots: "墨西哥城 · 坎昆 · 瓦哈卡", season: "11–4 月", blurb: "玛雅遗迹、海滩与浓烈风味。"),
        "BR": .init(spots: "里约 · 圣保罗 · 伊瓜苏", season: "12–3 月", blurb: "桑巴、海滩与亚马逊雨林。"),
        "PE": .init(spots: "库斯科 · 马丘比丘", season: "5–9 月（旱季）", blurb: "印加古道与安第斯高原。"),
        "AR": .init(spots: "布宜诺斯艾利斯 · 巴塔哥尼亚", season: "11–3 月", blurb: "探戈、冰川与广袤草原。"),
        "GR": .init(spots: "雅典 · 圣托里尼 · 米科诺斯", season: "5–10 月", blurb: "爱琴海的蓝白与古文明。"),
        "CH": .init(spots: "因特拉肯 · 策马特 · 卢塞恩", season: "6–9 / 12–3 月", blurb: "阿尔卑斯雪山与湖光山色。"),
        "IS": .init(spots: "雷克雅未克 · 黄金圈", season: "6–8 / 9–3 月（极光）", blurb: "火山、瀑布与北极光。"),
        "NL": .init(spots: "阿姆斯特丹 · 羊角村", season: "4–5 月（郁金香）", blurb: "运河、风车与郁金香田。"),
        "PT": .init(spots: "里斯本 · 波尔图 · 辛特拉", season: "4–10 月", blurb: "海风、花砖与法朵之声。"),
        "NO": .init(spots: "奥斯陆 · 卑尔根 · 峡湾", season: "6–8 / 9–3 月（极光）", blurb: "峡湾、午夜阳光与北极光。"),
        "MV": .init(spots: "马尔代夫", season: "11–4 月", blurb: "一岛一酒店的印度洋天堂。"),
        "IN": .init(spots: "德里 · 阿格拉 · 斋普尔", season: "10–3 月", blurb: "泰姬陵与多彩的人文盛宴。"),
    ]
}
