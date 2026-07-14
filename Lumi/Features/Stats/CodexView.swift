import SwiftUI
import SwiftData

/// 邮票收藏册：**收到的明信片上出现过的票**成册展示（集邮语义——票是别人寄给你的）。
/// 收集态**全派生、零新增存储**：遍历 isReceived 足迹的 `stampStyle` → StampKind →
/// 基础 / 地区 / 典藏 / 资源包 / 节日章 各归各区点亮；通用邮戳 = 收到过任意明信片。
/// 与「能不能用某张票寄出」（商店/会员/点亮国家）完全解耦。
struct CodexView: View {

    @Query private var footprints: [Footprint]
    @State private var selected: CodexEntry?

    /// 收到的明信片上的所有邮票（收藏册唯一口径）。
    private var receivedKinds: [StampKind] {
        footprints.filter { $0.isReceived }.map { StampKind(raw: $0.stampStyle) }
    }
    private var receivedBasics: Set<PostcardStamp> {
        Set(receivedKinds.compactMap { if case .basic(let b) = $0 { return b }; return nil })
    }
    private var receivedRegionalCodes: Set<String> {
        Set(receivedKinds.compactMap { if case .regional(let r) = $0 { return r.code }; return nil })
    }
    private var receivedPremiumIDs: Set<String> {
        Set(receivedKinds.compactMap { if case .premium(let p) = $0 { return p.id }; return nil })
    }
    /// 资源包条目键 "packID/itemID"。
    private var receivedPackKeys: Set<String> {
        Set(receivedKinds.compactMap {
            if case .pack(let p, let i) = $0 { return "\(p)/\(i)" }; return nil
        })
    }
    /// 已收集的节日章：收到过贴着该章的明信片（`fest:` 前缀）；旧卡按 地区×日期 兜底判定。
    private var collectedFestivals: Set<Festival> {
        Set(footprints.filter { $0.isReceived }.compactMap { fp -> Festival? in
            if case .festival(let f) = StampKind(raw: fp.stampStyle) { return f }
            return Festival.match(countryCode: fp.countryCode, date: fp.visitedAt)   // 旧卡兼容
        })
    }
    /// 收到过任意明信片 → 通用邮戳收集。
    private var hasReceivedAny: Bool { footprints.contains { $0.isReceived } }

    private var collectedTotal: Int {
        receivedBasics.count
            + RegionalStamp.all.filter { receivedRegionalCodes.contains($0.code) }.count
            + PremiumStamp.all.filter { receivedPremiumIDs.contains($0.id) }.count
            + newStampPacks.reduce(0) { sum, pack in
                sum + pack.items.filter { receivedPackKeys.contains("\(pack.id)/\($0.id)") }.count
            }
            + collectedFestivals.count
            + (hasReceivedAny ? 1 : 0)  // 通用邮戳
    }
    private var codexTotal: Int {
        PostcardStamp.allCases.count + RegionalStamp.all.count + PremiumStamp.all.count
            + newStampPacks.map(\.items.count).reduce(0, +)
            + Festival.allCases.count + 1
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                section("基础邮票", subtitle: "普通邮票 · 收到贴有此票的明信片即收集") {
                    HStack(spacing: 14) {
                        ForEach(PostcardStamp.allCases) { st in
                            let collected = receivedBasics.contains(st)
                            Button { selected = .basic(st, collected: collected); Haptics.selection() } label: {
                                cellFrame(unlocked: collected) {
                                    PostcardStampView(stamp: st).frame(width: 44, height: 53)
                                        .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.32)
                                } title: { Text(st.label) }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                section("地区邮票", subtitle: "地区特色 · 收到贴有此票的明信片即收集") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(RegionalStamp.all) { r in regionalCell(r) }
                    }
                }
                section("典藏邮票", subtitle: "手绘典藏 · 收到贴有此票的明信片即收集") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(PremiumStamp.all) { p in premiumCell(p) }
                    }
                }
                if !newStampPacks.isEmpty {
                    section("资源包邮票", subtitle: "商店扩充包 · 收到贴有此票的明信片即收集") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(newStampPacks) { pack in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(verbatim: pack.localizedName)
                                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.text)
                                    LazyVGrid(columns: cols, spacing: 14) {
                                        ForEach(pack.items) { item in packItemCell(pack, item) }
                                    }
                                }
                            }
                        }
                    }
                }
                section("节日限定章", subtitle: "节日前后 5 天限时流通 · 收到贴此章的明信片即收集") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(Festival.allCases) { f in festivalCell(f) }
                    }
                }
                section("邮戳 Postmarks", subtitle: "寄达后由 Lumi 邮局盖上，仅收件人可见 · 更多国家/地区/节日邮戳将陆续为会员推出") {
                    HStack(spacing: 14) {
                        Button { selected = .postmark(collected: hasReceivedAny); Haptics.selection() } label: {
                            cellFrame(unlocked: hasReceivedAny) {
                                genericPostmark
                                    .grayscale(hasReceivedAny ? 0 : 1)
                                    .opacity(hasReceivedAny ? 1 : 0.4)
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
        .navigationTitle("邮票收藏册")
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
                Text("收到的明信片上的邮票，都收进这本收藏册")
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

    /// 资源包条目 cell：收到过贴此票的卡 → 彩色；没收到过 → 灰剪影。
    private func packItemCell(_ pack: ContentPack, _ item: PackItem) -> some View {
        let collected = receivedPackKeys.contains("\(pack.id)/\(item.id)")
        return cellFrame(unlocked: collected) {
            PackItemStampView(packID: pack.id, itemID: item.id)
                .frame(width: 48, height: 58)
                .grayscale(collected ? 0 : 1)
                .opacity(collected ? 1 : 0.32)
        } title: {
            Text(verbatim: item.localizedName)
        }
    }

    private func regionalCell(_ r: RegionalStamp) -> some View {
        let collected = receivedRegionalCodes.contains(r.code)
        return Button { selected = .regional(r, collected: collected); Haptics.selection() } label: {
            cellFrame(unlocked: collected) {
                RegionalStampView(stamp: r)
                    .frame(width: 48, height: 58)
                    .grayscale(collected ? 0 : 1)
                    .opacity(collected ? 1 : 0.32)
            } title: {
                Text(verbatim: collected ? "\(r.flag) \(r.displayName)" : r.displayName)
            }
        }.buttonStyle(.plain)
    }

    private func premiumCell(_ p: PremiumStamp) -> some View {
        let collected = receivedPremiumIDs.contains(p.id)
        return Button { selected = .premium(p, collected: collected); Haptics.selection() } label: {
            cellFrame(unlocked: collected) {
                Image(p.imageName)
                    .resizable().scaledToFit()
                    .frame(width: 48, height: 60)
                    .grayscale(collected ? 0 : 1)
                    .opacity(collected ? 1 : 0.34)
            } title: {
                Text(p.nameKey)
            } footnote: {
                if collected, let city = p.cityKey { return Text(city) }
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

    /// 统一卡片框：贴图 + 名称 +（可选）解锁提示；未收集整体压暗。
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

// MARK: - 收藏册条目 & 详情半屏弹窗

/// 收藏册里可点开详情的条目（带收集态）。
enum CodexEntry: Identifiable {
    case regional(RegionalStamp, collected: Bool)
    case premium(PremiumStamp, collected: Bool)
    case festival(Festival, collected: Bool)
    case basic(PostcardStamp, collected: Bool)
    case postmark(collected: Bool)

    var id: String {
        switch self {
        case .regional(let r, _): return "r-\(r.code)"
        case .premium(let p, _):  return "p-\(p.id)"
        case .festival(let f, _): return "f-\(f.rawValue)"
        case .basic(let b, _):    return "b-\(b.rawValue)"
        case .postmark:           return "postmark"
        }
    }
}

/// 半屏详情：放大贴图 + 名称 + 收集/使用说明（怎么收集、寄件方怎么用得上）。
struct CodexDetailSheet: View {
    let entry: CodexEntry

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
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x0F0F1B).ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    // MARK: 放大贴图

    @ViewBuilder private var art: some View {
        switch entry {
        case .regional(let r, let collected):
            RegionalStampView(stamp: r)
                .frame(width: 118, height: 142)
                .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.4)
        case .premium(let p, let collected):
            Image(p.imageName).resizable().scaledToFit()
                .frame(width: 118, height: 148)
                .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.45)
        case .festival(let f, let collected):
            Image(f.imageName).resizable().scaledToFit()
                .frame(width: 128, height: 150)
                .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.4)
        case .basic(let b, let collected):
            PostcardStampView(stamp: b).frame(width: 110, height: 132)
                .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.5)
        case .postmark(let collected):
            VStack(spacing: 2) {
                Text(verbatim: "LUMI").font(.system(size: 18, weight: .bold))
                Text(verbatim: "✦").font(.system(size: 15))
            }
            .foregroundStyle(Color(hex: 0x6B4A2A))
            .frame(width: 110, height: 110)
            .overlay(Circle().stroke(Color(hex: 0x6B4A2A), lineWidth: 3))
            .background(Circle().fill(Color(hex: 0xE4D4B2).opacity(0.9)))
            .rotationEffect(.degrees(-8))
            .grayscale(collected ? 0 : 1).opacity(collected ? 1 : 0.5)
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
        case .basic(let b, _):
            Text(b.label).font(Typo.serif(23)).foregroundStyle(Color.text)
        case .postmark:
            Text("通用邮戳").font(Typo.serif(23)).foregroundStyle(Color.text)
        }
    }

    private var collected: Bool {
        switch entry {
        case .regional(_, let c), .premium(_, let c), .festival(_, let c),
             .basic(_, let c), .postmark(let c):
            return c
        }
    }

    private var stateChip: some View {
        (collected ? Text("已收集") : Text("未收集"))
            .font(.system(size: 10, weight: .bold)).tracking(1)
            .foregroundStyle(collected ? Color.grn : Color.muted)
            .padding(.vertical, 4).padding(.horizontal, 11)
            .background((collected ? Color.grn : Color.muted).opacity(0.13), in: Capsule())
    }

    // MARK: 说明行

    @ViewBuilder private var infoRows: some View {
        switch entry {
        case .regional(let r, _):
            infoRow("收集方式", Text("收到贴有此票的明信片即收集"))
            infoRow("流通条件", Text("点亮 \(r.displayName) 解锁"))
            infoRow("使用限制", Text("仅限该国足迹的明信片"))
        case .premium(let p, _):
            infoRow("收集方式", Text("收到贴有此票的明信片即收集"))
            infoRow("流通条件", Text("成为终身会员，并点亮该国家"))
            if let city = p.cityKey {
                infoRow("使用限制", Text(city) + Text(verbatim: " · ") + Text("仅限该城市足迹的明信片"))
            } else {
                infoRow("使用限制", Text("仅限该国足迹的明信片"))
            }
        case .festival(let f, _):
            infoRow("收集方式", Text("收到贴此章的明信片即可收集"))
            infoRow("可用窗口", Text(verbatim: f.windowText))
            infoRow("适用地区", Text(f.regionKey))
            infoRow("使用限制", Text("节日前后 5 天，寄该地区足迹的明信片可选用"))
        case .basic:
            infoRow("收集方式", Text("收到贴有此票的明信片即收集"))
            infoRow("使用限制", Text("任意明信片可选"))
        case .postmark:
            infoRow("收集方式", Text("收到任意一张明信片即收集"))
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
