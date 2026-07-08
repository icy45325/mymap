import SwiftUI
import SwiftData

/// 收集图鉴：地区邮票 / 节日限定章 / 基础邮票·邮戳 成册展示。
/// 解锁态**全派生、零新增存储**：
/// - 地区邮票 = 点亮过该国（litCountryCodes）
/// - 节日章 = 收到过命中该节日窗口的明信片（isReceived 足迹 × Festival.match）
/// - 基础邮票 & 通用邮戳 = 默认解锁（陈列）
struct CodexView: View {

    @Query private var footprints: [Footprint]
    @ObservedObject private var plus = PlusStore.shared
    @State private var selected: CodexEntry?

    private var litCodes: Set<String> { Set(footprints.compactMap { $0.countryCode }) }

    /// 已收集的节日章：收到过贴着该章的明信片（`fest:` 前缀）；旧卡按 地区×日期 兜底判定。
    private var collectedFestivals: Set<Festival> {
        Set(footprints.filter { $0.isReceived }.compactMap { fp -> Festival? in
            if case .festival(let f) = StampKind(raw: fp.stampStyle) { return f }
            return Festival.match(countryCode: fp.countryCode, date: fp.visitedAt)   // 旧卡兼容
        })
    }

    private var unlockedRegionalCount: Int {
        RegionalStamp.all.filter { litCodes.contains($0.code) }.count
    }
    /// 可用的典藏票数（Plus + 点亮该国）。
    private var usablePremiumCount: Int {
        guard plus.isPlus else { return 0 }
        return PremiumStamp.all.filter { litCodes.contains($0.code) }.count
    }
    private var collectedTotal: Int {
        unlockedRegionalCount + usablePremiumCount + collectedFestivals.count
            + PostcardStamp.allCases.count + 1  // +1 通用邮戳
    }
    private var codexTotal: Int {
        RegionalStamp.all.count + PremiumStamp.all.count + Festival.allCases.count
            + PostcardStamp.allCases.count + 1
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                section("基础邮票", subtitle: "普通邮票 · 默认解锁，任意明信片可选") {
                    HStack(spacing: 14) {
                        ForEach(PostcardStamp.allCases) { st in
                            Button { selected = .basic(st); Haptics.selection() } label: {
                                cellFrame(unlocked: true) {
                                    PostcardStampView(stamp: st).frame(width: 44, height: 53)
                                } title: { Text(st.label) }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                section("地区邮票", subtitle: "点亮该国家即解锁 · 仅限该国足迹的明信片") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(RegionalStamp.all) { r in regionalCell(r) }
                    }
                }
                section("典藏邮票 · PLUS", subtitle: "终身会员专属 · 点亮该国家后，寄该地足迹的明信片可选用") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(PremiumStamp.all) { p in premiumCell(p) }
                    }
                }
                if !newStampPacks.isEmpty {
                    section("资源包 · 商店", subtitle: "来自商店的扩充邮票包 · 拥有后寄对应足迹的明信片可选用") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(newStampPacks) { pack in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Text(verbatim: pack.localizedName)
                                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.text)
                                        if !PackStore.shared.owns(pack) {
                                            Image(systemName: "lock.fill").font(.system(size: 9))
                                                .foregroundStyle(Color.muted)
                                        }
                                    }
                                    LazyVGrid(columns: cols, spacing: 14) {
                                        ForEach(pack.items) { item in packItemCell(pack, item) }
                                    }
                                }
                            }
                        }
                    }
                }
                section("节日限定章", subtitle: "节日前后 5 天限时可用（地区性节日仅限该地区足迹）· 收到贴此章的明信片即收集") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(Festival.allCases) { f in festivalCell(f) }
                    }
                }
                section("邮戳 Postmarks", subtitle: "寄达后由 Lumi 邮局盖上，仅收件人可见 · 更多国家/地区/节日邮戳将陆续为会员推出") {
                    HStack(spacing: 14) {
                        Button { selected = .postmark; Haptics.selection() } label: {
                            cellFrame(unlocked: true) {
                                genericPostmark
                            } title: { Text("通用邮戳") }
                        }.buttonStyle(.plain)
                        comingSoonCell
                        Color.clear.frame(maxWidth: .infinity)   // 占位对齐三列宽度
                    }
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 22).padding(.top, 14)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("收集图鉴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $selected) { CodexDetailSheet(entry: $0) }
    }

    // MARK: - 头部进度

    private var progressHeader: some View {
        HStack(spacing: 16) {
            RingProgress(fraction: codexTotal > 0 ? Double(collectedTotal) / Double(codexTotal) : 0,
                         size: 74) {
                Text("\(collectedTotal)")
                    .font(Typo.serif(22)).foregroundStyle(Color.text)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("已收集 \(collectedTotal) / \(codexTotal)")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                Text("邮票、邮戳与节日章都收进这本图鉴")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(LinearGradient(colors: [Color.nPurple.opacity(0.16), Color.nPink.opacity(0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 分区

    private func section<C: View>(_ title: LocalizedStringKey, subtitle: LocalizedStringKey,
                                  @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).tracking(1).foregroundStyle(Color.muted)
            Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.faint)
            content()
        }
    }

    // MARK: - 单元格

    /// 商店里的新增邮票包（镜像包除外——它们已在各自分区展示）。
    private var newStampPacks: [ContentPack] {
        PackCatalog.shared.packs(in: .stamp).filter { pack in
            pack.items.contains { $0.legacyRaw == nil }
        }
    }

    /// 资源包条目 cell：拥有 → 彩色；未拥有 → 灰。
    private func packItemCell(_ pack: ContentPack, _ item: PackItem) -> some View {
        let owned = PackStore.shared.owns(pack)
        return cellFrame(unlocked: owned) {
            PackItemStampView(packID: pack.id, itemID: item.id)
                .frame(width: 48, height: 58)
                .grayscale(owned ? 0 : 1)
                .opacity(owned ? 1 : 0.32)
        } title: {
            Text(verbatim: item.localizedName)
        }
    }

    private func regionalCell(_ r: RegionalStamp) -> some View {
        let unlocked = litCodes.contains(r.code)
        return Button { selected = .regional(r, unlocked: unlocked); Haptics.selection() } label: {
            cellContent(r, unlocked: unlocked)
        }.buttonStyle(.plain)
    }

    private func cellContent(_ r: RegionalStamp, unlocked: Bool) -> some View {
        cellFrame(unlocked: unlocked) {
            RegionalStampView(stamp: r)
                .frame(width: 48, height: 58)
                .grayscale(unlocked ? 0 : 1)
                .opacity(unlocked ? 1 : 0.32)
        } title: {
            Text(verbatim: unlocked ? "\(r.flag) \(r.displayName)" : r.displayName)
        } footnote: {
            unlocked ? nil : Text("点亮 \(r.displayName) 解锁")
        }
    }

    private func premiumCell(_ p: PremiumStamp) -> some View {
        let lit = litCodes.contains(p.code)
        let usable = plus.isPlus && lit
        let country = Locale.current.localizedString(forRegionCode: p.code) ?? p.code
        return Button { selected = .premium(p, usable: usable); Haptics.selection() } label: {
            cellFrame(unlocked: usable) {
                Image(p.imageName)
                    .resizable().scaledToFit()
                    .frame(width: 48, height: 60)
                    .grayscale(usable ? 0 : 1)
                    .opacity(usable ? 1 : 0.34)
                    .overlay(alignment: .topTrailing) {
                        if !plus.isPlus {
                            Image(systemName: "lock.fill").font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(3).background(.black.opacity(0.55), in: Circle())
                                .offset(x: 5, y: -5)
                        }
                    }
            } title: {
                Text(p.nameKey)
            } footnote: {
                if !plus.isPlus { return Text("终身会员解锁") }
                if !lit { return Text("点亮 \(country) 解锁") }
                if let city = p.cityKey { return Text(city) }
                return nil
            }
        }.buttonStyle(.plain)
    }

    private func festivalCell(_ f: Festival) -> some View {
        let collected = collectedFestivals.contains(f)
        return Button { selected = .festival(f, collected: collected); Haptics.selection() } label: {
            festivalContent(f, collected: collected)
        }.buttonStyle(.plain)
    }

    private func festivalContent(_ f: Festival, collected: Bool) -> some View {
        cellFrame(unlocked: collected) {
            Image(f.imageName)
                .resizable().scaledToFit()
                .frame(width: 52, height: 62)
                .grayscale(collected ? 0 : 1)
                .opacity(collected ? 1 : 0.3)
        } title: {
            Text(f.titleKey)
        } footnote: {
            collected ? nil : Text(verbatim: f.windowText)
        }
    }

    /// 统一卡片框：贴图 + 名称 +（可选）解锁提示；未解锁整体压暗。
    private func cellFrame<S: View>(unlocked: Bool,
                                    @ViewBuilder _ art: () -> S,
                                    @ViewBuilder title: () -> Text,
                                    footnote: () -> Text? = { nil }) -> some View {
        VStack(spacing: 6) {
            art().frame(height: 62)
            title()
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(unlocked ? Color.text : Color.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let fn = footnote() {
                fn.font(.system(size: 8.5)).foregroundStyle(Color.faint)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(unlocked ? Color.nPurple.opacity(0.35) : Color.line, lineWidth: 1))
    }

    /// 「敬请期待」占位卡：未来按 国家/地区/节日 扩充的邮戳位（不计入进度）。
    private var comingSoonCell: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.line, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                Text(verbatim: "✦").font(.system(size: 18)).foregroundStyle(Color.faint)
            }
            .frame(width: 48, height: 48)
            .frame(height: 62)
            Text("敬请期待").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(Color.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.line.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    /// 通用 LUMI 圆戳（陈列版，放大）。
    private var genericPostmark: some View {
        VStack(spacing: 1) {
            Text(verbatim: "LUMI").font(.system(size: 8, weight: .bold))
            Text(verbatim: "✦").font(.system(size: 7))
        }
        .foregroundStyle(Color(hex: 0x6B4A2A))
        .frame(width: 48, height: 48)
        .overlay(Circle().stroke(Color(hex: 0x6B4A2A), lineWidth: 1.4))
        .background(Circle().fill(Color(hex: 0xE4D4B2).opacity(0.85)))
        .rotationEffect(.degrees(-8))
    }
}

// MARK: - 图鉴条目 & 详情半屏弹窗

/// 图鉴里可点开详情的条目（带解锁/收集态）。
enum CodexEntry: Identifiable {
    case regional(RegionalStamp, unlocked: Bool)
    case premium(PremiumStamp, usable: Bool)
    case festival(Festival, collected: Bool)
    case basic(PostcardStamp)
    case postmark

    var id: String {
        switch self {
        case .regional(let r, _): return "r-\(r.code)"
        case .premium(let p, _):  return "p-\(p.id)"
        case .festival(let f, _): return "f-\(f.rawValue)"
        case .basic(let b):       return "b-\(b.rawValue)"
        case .postmark:           return "postmark"
        }
    }
}

/// 半屏详情：放大贴图 + 名称 + 解锁/使用说明（怎么获得、什么时候能用、贴在哪）。
struct CodexDetailSheet: View {
    let entry: CodexEntry
    @ObservedObject private var plus = PlusStore.shared
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.line).frame(width: 40, height: 4).padding(.top, 11)
            Spacer(minLength: 12)
            art
                .frame(height: 150)
            title
                .padding(.top, 14)
            stateChip
                .padding(.top, 8)
            VStack(spacing: 9) { infoRows }
                .padding(.top, 18).padding(.horizontal, 30)
            if case .premium = entry, !plus.isPlus {
                Button { showPaywall = true } label: {
                    Text("成为终身会员")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(LinearGradient.neonH, in: Capsule())
                }
                .padding(.top, 16).padding(.horizontal, 30)
            }
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x0F0F1B).ignoresSafeArea())
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    // MARK: 放大贴图

    @ViewBuilder private var art: some View {
        switch entry {
        case .regional(let r, let unlocked):
            RegionalStampView(stamp: r)
                .frame(width: 118, height: 142)
                .grayscale(unlocked ? 0 : 1).opacity(unlocked ? 1 : 0.4)
        case .premium(let p, let usable):
            Image(p.imageName).resizable().scaledToFit()
                .frame(width: 118, height: 148)
                .grayscale(usable ? 0 : 1).opacity(usable ? 1 : 0.45)
        case .festival(let f, let collected):
            Image(f.imageName).resizable().scaledToFit()
                .frame(width: 128, height: 150)
                .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.4)
        case .basic(let b):
            PostcardStampView(stamp: b).frame(width: 110, height: 132)
        case .postmark:
            VStack(spacing: 2) {
                Text(verbatim: "LUMI").font(.system(size: 18, weight: .bold))
                Text(verbatim: "✦").font(.system(size: 15))
            }
            .foregroundStyle(Color(hex: 0x6B4A2A))
            .frame(width: 110, height: 110)
            .overlay(Circle().stroke(Color(hex: 0x6B4A2A), lineWidth: 3))
            .background(Circle().fill(Color(hex: 0xE4D4B2).opacity(0.9)))
            .rotationEffect(.degrees(-8))
        }
    }

    // MARK: 名称 / 状态

    @ViewBuilder private var title: some View {
        switch entry {
        case .regional(let r, _):
            Text(verbatim: "\(r.flag) \(r.displayName)").font(Typo.serif(23)).foregroundStyle(Color.text)
        case .premium(let p, _):
            Text(p.nameKey).font(Typo.serif(23)).foregroundStyle(Color.text)
        case .festival(let f, _):
            Text(f.titleKey).font(Typo.serif(23)).foregroundStyle(Color.text)
        case .basic(let b):
            Text(b.label).font(Typo.serif(23)).foregroundStyle(Color.text)
        case .postmark:
            Text("通用邮戳").font(Typo.serif(23)).foregroundStyle(Color.text)
        }
    }

    @ViewBuilder private var stateChip: some View {
        let (text, on): (LocalizedStringKey, Bool) = {
            switch entry {
            case .regional(_, let u): return (u ? "已解锁" : "未解锁", u)
            case .premium(_, let u):  return (u ? "已解锁" : "未解锁", u)
            case .festival(_, let c): return (c ? "已收集" : "未收集", c)
            case .basic, .postmark:   return ("默认解锁", true)
            }
        }()
        Text(text)
            .font(.system(size: 10, weight: .bold)).tracking(1)
            .foregroundStyle(on ? Color.grn : Color.muted)
            .padding(.vertical, 4).padding(.horizontal, 11)
            .background((on ? Color.grn : Color.muted).opacity(0.13), in: Capsule())
    }

    // MARK: 说明行

    @ViewBuilder private var infoRows: some View {
        switch entry {
        case .regional(let r, _):
            infoRow("解锁条件", Text("点亮 \(r.displayName) 解锁"))
            infoRow("使用限制", Text("仅限该国足迹的明信片"))
            infoRow("用法", Text("寄明信片时在邮票选择器中选用"))
        case .premium(let p, _):
            infoRow("解锁条件", Text("成为终身会员，并点亮该国家"))
            if let city = p.cityKey {
                infoRow("使用限制", Text(city) + Text(verbatim: " · ") + Text("仅限该城市足迹的明信片"))
            } else {
                infoRow("使用限制", Text("仅限该国足迹的明信片"))
            }
            infoRow("用法", Text("寄明信片时在邮票选择器中选用"))
        case .festival(let f, _):
            infoRow("可用窗口", Text(verbatim: f.windowText))
            infoRow("适用地区", Text(f.regionKey))
            infoRow("使用限制", Text("节日前后 5 天，寄该地区足迹的明信片可选用"))
            infoRow("收集方式", Text("收到贴此章的明信片即可收集"))
        case .basic:
            infoRow("使用限制", Text("任意明信片可选"))
            infoRow("用法", Text("寄明信片时在邮票选择器中选用"))
        case .postmark:
            infoRow("说明", Text("邮局盖章：明信片寄达后由 Lumi 邮局盖上，仅收件人翻面可见"))
            infoRow("后续", Text("更多按国家/地区/节日区分的邮戳将为终身会员推出"))
        }
    }

    private func infoRow(_ label: LocalizedStringKey, _ value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.faint)
                .frame(width: 62, alignment: .leading)
            value
                .font(.system(size: 12.5)).foregroundStyle(Color(hex: 0xC9C2D6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack { CodexView() }
        .modelContainer(for: [Footprint.self, Trip.self, Card.self], inMemory: true)
}
