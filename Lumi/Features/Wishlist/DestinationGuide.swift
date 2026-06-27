import Foundation

/// 目的地小指南：心愿卡上展示「推荐地点 / 最佳季节 / 游玩简述」。
/// 精选静态内容，**三语**（中 / 英 / 阿），按系统语言解析；按国家码取。
struct DestinationGuide {
    let spots: String      // 推荐地点
    let season: String     // 最佳季节
    let blurb: String      // 一句游玩简述

    static func of(_ code: String?) -> DestinationGuide? {
        guard let cc = code?.uppercased(), let r = table[cc] else { return nil }
        let i = langIndex
        return DestinationGuide(spots: r.0[i], season: r.1[i], blurb: r.2[i])
    }

    /// 0 = 中文，1 = 英文，2 = 阿语；其余语言默认英文。
    private static var langIndex: Int {
        switch Locale.current.language.languageCode?.identifier {
        case "zh": return 0
        case "ar": return 2
        default:   return 1
        }
    }

    // 每个字段一个 [zh, en, ar] 三元组。
    private static let table: [String: ([String], [String], [String])] = [
        "JP": (["东京 · 京都 · 富士山 · 大阪", "Tokyo · Kyoto · Mt. Fuji · Osaka", "طوكيو · كيوتو · جبل فوجي · أوساكا"],
               ["春赏樱 / 秋赏枫", "Spring blossoms / autumn leaves", "أزهار الربيع / أوراق الخريف"],
               ["古今交融、四季分明，美食与温泉的国度。", "Old meets new across four seasons — cuisine and hot springs.", "أرض تمتزج فيها الأصالة والحداثة عبر فصول أربعة، مطبخ وينابيع ساخنة."]),
        "FR": (["巴黎 · 普罗旺斯 · 尼斯", "Paris · Provence · Nice", "باريس · بروفانس · نيس"],
               ["5–9 月", "May–Sep", "مايو–سبتمبر"],
               ["浪漫之都与薰衣草田，艺术与美食之乡。", "The city of romance, lavender fields, art and gastronomy.", "مدينة الرومانسية وحقول الخزامى والفن والمطبخ الراقي."]),
        "IT": (["罗马 · 威尼斯 · 佛罗伦萨", "Rome · Venice · Florence", "روما · البندقية · فلورنسا"],
               ["4–6 / 9–10 月", "Apr–Jun / Sep–Oct", "أبريل–يونيو / سبتمبر–أكتوبر"],
               ["古罗马遗迹、文艺复兴与地中海风情。", "Roman ruins, Renaissance art and Mediterranean charm.", "آثار رومانية وفن النهضة وسحر المتوسط."]),
        "ES": (["巴塞罗那 · 马德里 · 塞维利亚", "Barcelona · Madrid · Seville", "برشلونة · مدريد · إشبيلية"],
               ["3–5 / 9–11 月", "Mar–May / Sep–Nov", "مارس–مايو / سبتمبر–نوفمبر"],
               ["高迪建筑、弗拉明戈与阳光海岸。", "Gaudí architecture, flamenco and sunny coasts.", "عمارة غاودي والفلامنكو وسواحل مشمسة."]),
        "GB": (["伦敦 · 爱丁堡 · 湖区", "London · Edinburgh · Lake District", "لندن · إدنبرة · منطقة البحيرات"],
               ["5–9 月", "May–Sep", "مايو–سبتمبر"],
               ["古典与现代交织，城堡与博物馆。", "Classic and modern entwined — castles and museums.", "مزيج من الكلاسيكية والحداثة، قلاع ومتاحف."]),
        "US": (["纽约 · 旧金山 · 国家公园", "New York · San Francisco · National Parks", "نيويورك · سان فرانسيسكو · المتنزهات الوطنية"],
               ["全年（各地不同）", "Year-round (varies by region)", "طوال العام (يختلف حسب المنطقة)"],
               ["从都市天际线到壮阔自然。", "From city skylines to vast wilderness.", "من أفق المدن إلى الطبيعة الشاسعة."]),
        "TH": (["曼谷 · 清迈 · 普吉", "Bangkok · Chiang Mai · Phuket", "بانكوك · شيانغ ماي · بوكيت"],
               ["11–2 月（凉季）", "Nov–Feb (cool season)", "نوفمبر–فبراير (الموسم البارد)"],
               ["寺庙、海岛与街头美食的微笑国度。", "Temples, islands and street food in the land of smiles.", "معابد وجزر وأطعمة الشارع في بلد الابتسامات."]),
        "SG": (["滨海湾 · 圣淘沙 · 乌节路", "Marina Bay · Sentosa · Orchard Rd", "خليج مارينا · سنتوسا · شارع أورشارد"],
               ["全年", "Year-round", "طوال العام"],
               ["花园城市，多元美食与现代地标。", "A garden city of diverse food and modern landmarks.", "مدينة حدائق بمأكولات متنوعة ومعالم حديثة."]),
        "KR": (["首尔 · 釜山 · 济州", "Seoul · Busan · Jeju", "سيول · بوسان · جيجو"],
               ["4–6 / 9–11 月", "Apr–Jun / Sep–Nov", "أبريل–يونيو / سبتمبر–نوفمبر"],
               ["潮流与传统并存，美食与综艺之地。", "Trend meets tradition — food and pop culture.", "حيث تلتقي الموضة بالتقاليد، طعام وثقافة شعبية."]),
        "VN": (["河内 · 下龙湾 · 会安", "Hanoi · Ha Long Bay · Hoi An", "هانوي · خليج ها لونغ · هوي آن"],
               ["11–4 月", "Nov–Apr", "نوفمبر–أبريل"],
               ["山海之间的烟火气与法式风情。", "Buzzing life and French flair between mountains and sea.", "حياة نابضة ولمسة فرنسية بين الجبال والبحر."]),
        "ID": (["巴厘岛 · 日惹 · 科莫多", "Bali · Yogyakarta · Komodo", "بالي · يوجياكارتا · كومودو"],
               ["5–9 月（旱季）", "May–Sep (dry season)", "مايو–سبتمبر (الموسم الجاف)"],
               ["海岛、火山与古庙的热带天堂。", "A tropical paradise of islands, volcanoes and ancient temples.", "جنة استوائية من جزر وبراكين ومعابد قديمة."]),
        "AE": (["迪拜 · 阿布扎比", "Dubai · Abu Dhabi", "دبي · أبوظبي"],
               ["11–3 月", "Nov–Mar", "نوفمبر–مارس"],
               ["沙漠与摩天楼，奢华与传统并存。", "Deserts and skyscrapers, luxury and tradition.", "صحارٍ وناطحات سحاب، فخامة وتقاليد."]),
        "TR": (["伊斯坦布尔 · 卡帕多奇亚", "Istanbul · Cappadocia", "إسطنبول · كابادوكيا"],
               ["4–5 / 9–11 月", "Apr–May / Sep–Nov", "أبريل–مايو / سبتمبر–نوفمبر"],
               ["横跨欧亚，热气球与千年古城。", "Spanning two continents — balloons and ancient cities.", "تمتد عبر قارتين، مناطيد ومدن عريقة."]),
        "EG": (["开罗 · 卢克索 · 红海", "Cairo · Luxor · Red Sea", "القاهرة · الأقصر · البحر الأحمر"],
               ["10–4 月", "Oct–Apr", "أكتوبر–أبريل"],
               ["金字塔与尼罗河的千年文明。", "Millennia of civilization by the pyramids and the Nile.", "حضارة آلاف السنين عند الأهرامات والنيل."]),
        "MA": (["马拉喀什 · 非斯 · 撒哈拉", "Marrakech · Fes · Sahara", "مراكش · فاس · الصحراء"],
               ["3–5 / 9–11 月", "Mar–May / Sep–Nov", "مارس–مايو / سبتمبر–نوفمبر"],
               ["迷宫老城与沙漠星空。", "Labyrinth medinas and starlit deserts.", "مدن قديمة متاهية وصحارٍ تحت النجوم."]),
        "ZA": (["开普敦 · 克鲁格", "Cape Town · Kruger", "كيب تاون · كروجر"],
               ["10–4 月", "Oct–Apr", "أكتوبر–أبريل"],
               ["桌山、好望角与野生动物。", "Table Mountain, the Cape and wildlife safaris.", "جبل الطاولة والرأس والحياة البرية."]),
        "AU": (["悉尼 · 墨尔本 · 大堡礁", "Sydney · Melbourne · Great Barrier Reef", "سيدني · ملبورن · الحاجز المرجاني العظيم"],
               ["9–11 / 3–5 月", "Sep–Nov / Mar–May", "سبتمبر–نوفمبر / مارس–مايو"],
               ["海滩、珊瑚礁与辽阔内陆。", "Beaches, coral reefs and the vast outback.", "شواطئ وشعاب مرجانية وداخلية شاسعة."]),
        "NZ": (["皇后镇 · 南岛", "Queenstown · South Island", "كوينزتاون · الجزيرة الجنوبية"],
               ["12–2 月", "Dec–Feb", "ديسمبر–فبراير"],
               ["雪山湖泊与极限运动的纯净之地。", "Pristine peaks, lakes and adventure sports.", "قمم وبحيرات نقية ورياضات مغامرة."]),
        "CA": (["温哥华 · 班夫 · 多伦多", "Vancouver · Banff · Toronto", "فانكوفر · بانف · تورنتو"],
               ["6–9 月", "Jun–Sep", "يونيو–سبتمبر"],
               ["落基山脉、湖泊与枫叶国度。", "The Rockies, lakes and maple-leaf country.", "جبال روكي والبحيرات وبلد أوراق القيقب."]),
        "MX": (["墨西哥城 · 坎昆 · 瓦哈卡", "Mexico City · Cancún · Oaxaca", "مكسيكو سيتي · كانكون · أواكساكا"],
               ["11–4 月", "Nov–Apr", "نوفمبر–أبريل"],
               ["玛雅遗迹、海滩与浓烈风味。", "Mayan ruins, beaches and bold flavors.", "آثار المايا وشواطئ ونكهات جريئة."]),
        "BR": (["里约 · 圣保罗 · 伊瓜苏", "Rio · São Paulo · Iguazú", "ريو · ساو باولو · إجوازو"],
               ["12–3 月", "Dec–Mar", "ديسمبر–مارس"],
               ["桑巴、海滩与亚马逊雨林。", "Samba, beaches and the Amazon rainforest.", "السامبا والشواطئ وغابات الأمازون."]),
        "PE": (["库斯科 · 马丘比丘", "Cusco · Machu Picchu", "كوسكو · ماتشو بيتشو"],
               ["5–9 月（旱季）", "May–Sep (dry season)", "مايو–سبتمبر (الموسم الجاف)"],
               ["印加古道与安第斯高原。", "Inca trails and the Andean highlands.", "دروب الإنكا ومرتفعات الأنديز."]),
        "AR": (["布宜诺斯艾利斯 · 巴塔哥尼亚", "Buenos Aires · Patagonia", "بوينس آيرس · باتاغونيا"],
               ["11–3 月", "Nov–Mar", "نوفمبر–مارس"],
               ["探戈、冰川与广袤草原。", "Tango, glaciers and sweeping pampas.", "التانغو والأنهار الجليدية والسهوب الواسعة."]),
        "GR": (["雅典 · 圣托里尼 · 米科诺斯", "Athens · Santorini · Mykonos", "أثينا · سانتوريني · ميكونوس"],
               ["5–10 月", "May–Oct", "مايو–أكتوبر"],
               ["爱琴海的蓝白与古文明。", "Aegean blue-and-white and ancient civilization.", "أزرق وأبيض بحر إيجة وحضارة عريقة."]),
        "CH": (["因特拉肯 · 策马特 · 卢塞恩", "Interlaken · Zermatt · Lucerne", "إنترلاكن · زيرمات · لوسيرن"],
               ["6–9 / 12–3 月", "Jun–Sep / Dec–Mar", "يونيو–سبتمبر / ديسمبر–مارس"],
               ["阿尔卑斯雪山与湖光山色。", "Alpine peaks and lakeside scenery.", "قمم الألب ومناظر البحيرات."]),
        "IS": (["雷克雅未克 · 黄金圈", "Reykjavík · Golden Circle", "ريكيافيك · الدائرة الذهبية"],
               ["6–8 / 9–3 月（极光）", "Jun–Aug / Sep–Mar (auroras)", "يونيو–أغسطس / سبتمبر–مارس (الشفق)"],
               ["火山、瀑布与北极光。", "Volcanoes, waterfalls and the northern lights.", "براكين وشلالات والشفق القطبي."]),
        "NL": (["阿姆斯特丹 · 羊角村", "Amsterdam · Giethoorn", "أمستردام · جيتهورن"],
               ["4–5 月（郁金香）", "Apr–May (tulips)", "أبريل–مايو (التوليب)"],
               ["运河、风车与郁金香田。", "Canals, windmills and tulip fields.", "قنوات وطواحين وحقول توليب."]),
        "PT": (["里斯本 · 波尔图 · 辛特拉", "Lisbon · Porto · Sintra", "لشبونة · بورتو · سينترا"],
               ["4–10 月", "Apr–Oct", "أبريل–أكتوبر"],
               ["海风、花砖与法朵之声。", "Sea breeze, tiled façades and fado songs.", "نسيم البحر وواجهات القرميد وأغاني الفادو."]),
        "NO": (["奥斯陆 · 卑尔根 · 峡湾", "Oslo · Bergen · Fjords", "أوسلو · بيرغن · المضايق"],
               ["6–8 / 9–3 月（极光）", "Jun–Aug / Sep–Mar (auroras)", "يونيو–أغسطس / سبتمبر–مارس (الشفق)"],
               ["峡湾、午夜阳光与北极光。", "Fjords, midnight sun and northern lights.", "مضايق وشمس منتصف الليل والشفق القطبي."]),
        "MV": (["马尔代夫", "Maldives", "جزر المالديف"],
               ["11–4 月", "Nov–Apr", "نوفمبر–أبريل"],
               ["一岛一酒店的印度洋天堂。", "One-island-one-resort paradise in the Indian Ocean.", "جنة المحيط الهندي بجزيرة لكل منتجع."]),
        "IN": (["德里 · 阿格拉 · 斋普尔", "Delhi · Agra · Jaipur", "دلهي · أغرا · جايبور"],
               ["10–3 月", "Oct–Mar", "أكتوبر–مارس"],
               ["泰姬陵与多彩的人文盛宴。", "The Taj Mahal and a feast of vibrant culture.", "تاج محل ووليمة من الثقافة النابضة."]),
    ]
}
