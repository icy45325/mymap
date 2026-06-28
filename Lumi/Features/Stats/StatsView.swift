import SwiftUI
import SwiftData
import UIKit

/// 点亮成就（§4.4）· 暗夜霓虹 v2。
/// 环形概览 + 置顶展示 + 蜂巢徽章 + 分类筛选 + 即将解锁 + 大洲征服环。
struct StatsView: View {

    @Query private var footprints: [Footprint]

    @State private var categoryFilter: CatFilter = .all
    @State private var selectedBadge: Badge?
    @State private var celebrate: Badge?
    /// 用户手动钉选的置顶徽章 id（持久化；空 = 用默认「最高荣耀」）。
    @AppStorage("lumi.featuredBadgeID") private var pinnedID: String = ""

    private enum CatFilter: Hashable { case all, category(BadgeCategory), rare }

    private var stats: LumiStats { LumiStats(footprints: footprints) }
    private var board: BadgeBoard { stats.badgeBoard }

    /// 置顶展示：`"none"` = 用户选择「全部不置顶」(不展示)；手动钉选（且仍为已解锁）优先；
    /// 否则（空串，初始默认）回退到稀有度最高的已解锁徽章。
    private var featuredBadge: Badge? {
        if pinnedID == "none" { return nil }
        if !pinnedID.isEmpty,
           let pinned = board.badges.first(where: { $0.id == pinnedID && $0.state == .lit }) {
            return pinned
        }
        return board.featured
    }
    private var isManuallyPinned: Bool {
        !pinnedID.isEmpty && board.badges.contains { $0.id == pinnedID && $0.state == .lit }
    }


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    // —— 统计在上 ——
                    statsSummary
                    conquestSection
                    // —— 徽章墙在下 ——
                    badgesHeader
                    ringSummary
                    if let f = featuredBadge { showcase(f) }
                    SegmentBar(items: segmentItems, selection: $categoryFilter)
                    honeycomb
                    if let n = board.nextUp { nextUpSection(n) }
                    Color.clear.frame(height: 20)
                }
                .padding(.top, 16)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .onAppear {
            Analytics.log(.statsViewed(totalLit: stats.countries, percent: Int(stats.worldPercent.rounded())))
        }
        .sheet(item: $selectedBadge) { BadgeSheet(badge: $0, isFeatured: $0.id == featuredBadge?.id) }
        .overlay { if let c = celebrate { UnlockCelebration(badge: c) { celebrate = nil } } }
    }

    // MARK: - 头部 / 环形概览

    private var header: some View {
        Text("Achievements").font(Typo.serif(27)).padding(.horizontal, 26)
    }

    private var ringSummary: some View {
        HStack(spacing: 16) {
            RingProgress(fraction: board.total > 0 ? Double(board.unlockedCount) / Double(board.total) : 0,
                         size: 84) {
                VStack(spacing: 1) {
                    Text("\(Int((board.total > 0 ? Double(board.unlockedCount) / Double(board.total) : 0) * 100))%")
                        .font(Typo.serif(21)).foregroundStyle(Color.text)
                    Text("\(board.unlockedCount) / \(board.total)")
                        .font(.system(size: 9)).foregroundStyle(Color.muted)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("徽章收藏").font(Typo.serif(21))
                Text("\(board.unlockedCount) / \(board.total)")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 26)
    }

    // MARK: - 统计汇总（页面顶部）

    private var statsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(stats.countries)").font(Typo.serif(40)).foregroundStyle(Color.text)
                Text("/ \(Boundaries.shared.unMemberCount)")
                    .font(Typo.serif(20)).foregroundStyle(Color.muted)
                Spacer()
            }
            Text("已访问 UN 成员国").font(.system(size: 12)).foregroundStyle(Color.muted)
            HStack(spacing: 10) {
                summaryCard("\(stats.countries)", "国家", "/ \(stats.worldTotal)")
                summaryCard("\(stats.cities)", "城市", nil)
                summaryCard("\(stats.continentsCovered)", "大洲", "/ 7")
            }
        }
        .padding(.horizontal, 26)
    }

    private func summaryCard(_ value: String, _ label: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.localized).font(.system(size: 10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Color.muted).textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(Typo.serif(24)).foregroundStyle(Color.text)
                if let sub { Text(sub).font(.system(size: 11)).foregroundStyle(Color.faint) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13).padding(.horizontal, 13)
        .panelCard(14)
    }

    private var badgesHeader: some View {
        Text("徽章墙").font(.system(size: 13, weight: .semibold)).tracking(1)
            .foregroundStyle(Color.muted)
            .padding(.horizontal, 26).padding(.top, 4)
    }

    // MARK: - 置顶展示

    private func showcase(_ b: Badge) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(b.rarity.tierName.localized) · \(b.rarity.rawValue.uppercased())")
                    .font(.system(size: 10, weight: .heavy)).tracking(1.6)
                    .foregroundStyle(b.rarity.color)
                Text(b.name.localized).font(Typo.serif(25)).foregroundStyle(Color.text)
                Text(b.desc.localized).font(.system(size: 12)).foregroundStyle(Color(hex: 0xC9C2D6))
                    .frame(maxWidth: 195, alignment: .leading)
                Text("◆ 全球仅 \(b.ownership) 玩家拥有")
                    .font(.system(size: 10.5)).foregroundStyle(Color(hex: 0xE6C18C))
                    .padding(.top, 6)
            }
            Spacer()
            HexBadge(badge: b, size: 70)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.nOrange.opacity(0.2), Color.nPink.opacity(0.12), Color.nPurple.opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.nOrange.opacity(0.45), lineWidth: 1))
        .overlay(alignment: .topTrailing) { pinControl }
        .contentShape(Rectangle())
        .onTapGesture { celebrate = b }
        .padding(.horizontal, 22)
    }

    /// 置顶角标：手动钉选时给「取消置顶」；自动「最高荣耀」时也可选择「不展示」(全部不置顶)。
    @ViewBuilder private var pinControl: some View {
        if isManuallyPinned {
            Button { pinnedID = "none" } label: {
                Label("取消置顶", systemImage: "pin.slash.fill")
                    .font(.system(size: 9, weight: .bold)).tracking(0.5)
                    .foregroundStyle(Color.nOrange)
                    .padding(.vertical, 5).padding(.horizontal, 9)
                    .background(Color.black.opacity(0.32), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(12)
        } else {
            Menu {
                Button("不展示徽章", systemImage: "eye.slash") { pinnedID = "none" }
            } label: {
                Text("桂冠 · 最高荣耀").font(.system(size: 9, weight: .bold)).tracking(1)
                    .foregroundStyle(Color.nOrange).padding(14)
            }
        }
    }

    // MARK: - 徽章墙（3 列网格，给插画徽章更大展示空间）

    private var honeycomb: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)
        return LazyVGrid(columns: cols, spacing: 18) {
            ForEach(sortedBadges) { b in badgeCell(b) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    /// 排序：已点亮在最前 → 进行中按点亮进度从高到低 → 完全未解锁在最后；同档保持原顺序。
    private var sortedBadges: [Badge] {
        func rank(_ b: Badge) -> Double {
            switch b.state {
            case .lit:    return 100                 // 已点亮最前
            case .prog:   return b.progress ?? 0     // 进行中按进度 0…1
            case .locked: return -1                  // 完全未解锁最后
            }
        }
        return board.badges.enumerated()
            .sorted { a, b in
                let ra = rank(a.element), rb = rank(b.element)
                return ra != rb ? ra > rb : a.offset < b.offset
            }
            .map(\.element)
    }

    /// 单元：徽章 + 名称。点击看「是什么 / 怎么得到」。插画徽章自带名字，不再重复文字。
    private func badgeCell(_ b: Badge) -> some View {
        VStack(spacing: 6) {
            HexBadge(badge: b, size: 96, dimmed: !matches(b))
            if b.imageName == nil {
                Text(b.name.localized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(matches(b) ? Color.muted : Color.faint)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { selectedBadge = b }
    }

    private func matches(_ b: Badge) -> Bool {
        switch categoryFilter {
        case .all: return true
        case .category(let c): return b.category == c
        case .rare: return b.rarity == .epic || b.rarity == .legendary
        }
    }

    /// 只列出实际有徽章的分类，避免出现空筛选。
    private var segmentItems: [(value: CatFilter, label: String)] {
        var items: [(value: CatFilter, label: String)] = [(.all, "全部")]
        for cat in [BadgeCategory.continent, .milestone, .streak]
        where board.badges.contains(where: { $0.category == cat }) {
            items.append((.category(cat), cat.displayName))
        }
        if board.badges.contains(where: { $0.rarity == .epic || $0.rarity == .legendary }) {
            items.append((.rare, "稀有"))
        }
        return items
    }

    // MARK: - 即将解锁

    private func nextUpSection(_ b: Badge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("即将解锁 Next up").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
                .padding(.horizontal, 26)
            Button { selectedBadge = b } label: {     // 进行中：开详情看条件，不弹点亮效果
                HStack(spacing: 13) {
                    HexBadge(badge: b, size: 46)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(b.name.localized) · \(b.rarity.tierName.localized)").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.text)
                        Text("即将解锁 · \(b.progressText ?? "")").font(.system(size: 10.5))
                            .foregroundStyle(Color.muted)
                        NeonBar(fraction: b.progress ?? 0, height: 8)
                    }
                    Spacer()
                }
                .padding(13).panelCard(16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
        }
    }

    // MARK: - 大洲征服

    private var conquestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("大洲征服 Conquest").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
                .padding(.horizontal, 26)
            HStack(alignment: .top, spacing: 8) {
                ForEach(stats.conquest) { c in
                    VStack(spacing: 7) {
                        RingProgress(fraction: Double(c.percent) / 100, size: 56, lineWidth: 5,
                                     colors: [c.region.color, c.region.color.opacity(0.5)]) {
                            Text("\(c.percent)%").font(Typo.serif(13)).foregroundStyle(Color.text)
                        }
                        Text(c.region.displayName.localized).font(.system(size: 10)).foregroundStyle(Color.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - 徽章详情 Sheet

private struct BadgeSheet: View {
    let badge: Badge
    /// 是否为成就页当前「置顶展示」的徽章（含自动「最高荣耀」）；决定按钮显示置顶 / 取消置顶，保持与展示一致。
    let isFeatured: Bool

    @State private var shareImage: Image?
    @AppStorage("lumi.featuredBadgeID") private var pinnedID: String = ""
    private var isPinned: Bool { isFeatured }

    private static let dateFormat: Date.FormatStyle = .dateTime.year().month().day()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Capsule().fill(Color.line).frame(width: 40, height: 4).padding(.top, 11)

                // ——— 主角：放大的徽章，光晕只作底部基座（不再整圈罩在大图上）———
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(RadialGradient(colors: [badge.color.opacity(badge.state == .lit ? 0.6 : 0.2), .clear],
                                             center: .center, startRadius: 2, endRadius: 130))
                        .frame(width: 250, height: 100)
                        .blur(radius: 24)
                        .offset(y: -6)
                    // 用 HexBadge（无全息流光）展示大图，去掉徽章上层炫光，只保留底部光晕
                    HexBadge(badge: badge, size: 200)
                }
                .frame(height: 290)
                .padding(.top, 2)

                Text(badge.name.localized).font(Typo.serif(30)).foregroundStyle(Color.text)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                Text("\(badge.rarity.tierName.localized) · \(badge.rarity.rawValue.uppercased())")
                    .font(.system(size: 11, weight: .heavy)).tracking(1.8)
                    .foregroundStyle(badge.rarity.color).padding(.top, 6)

                // ——— 操作：pin + 分享，小按钮一排（仅已解锁）———
                if badge.state == .lit {
                    HStack(spacing: 10) {
                        Button { pinnedID = isPinned ? "none" : badge.id } label: {
                            compactAction(isPinned ? "取消置顶" : "置顶",
                                          systemImage: isPinned ? "pin.slash.fill" : "pin.fill",
                                          tint: Color.nOrange, filled: !isPinned)
                        }
                        .buttonStyle(.plain)

                        if let shareImage {
                            ShareLink(item: shareImage,
                                      preview: SharePreview(badge.name.localized, image: shareImage)) {
                                compactAction("分享", systemImage: "square.and.arrow.up",
                                              tint: Color.nCyan, filled: false)
                            }
                        }
                    }
                    .padding(.top, 16)
                }

                // ——— 次要内容：解锁条件 + 数据（更安静）———
                VStack(spacing: 10) {
                    Text((badge.state == .lit ? "已解锁" : "解锁条件").localized)
                        .font(.system(size: 10, weight: .bold)).tracking(1.5)
                        .foregroundStyle(badge.state == .lit ? Color.grn : Color.nCyan)
                    Text(badge.desc.localized).font(.system(size: 12.5)).foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center)
                    if badge.state == .prog, let p = badge.progress {
                        NeonBar(fraction: p, height: 7).frame(height: 7)
                        Text(badge.progressText ?? "").font(.system(size: 11)).foregroundStyle(Color.muted)
                    }
                    HStack(spacing: 10) {
                        statBox(badge.ownership, "全球持有率")
                        statBox(stateValue, stateLabel)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 22).padding(.horizontal, 26).padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: 0x0F0F1B).ignoresSafeArea())
        .onAppear {
            if badge.state == .lit, shareImage == nil {
                shareImage = ShareRender.image(BadgeShareCard(badge: badge))
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    /// 小号操作按钮（按内容自适应宽度，pin/share 并排用）。
    private func compactAction(_ title: LocalizedStringKey, systemImage: String,
                               tint: Color, filled: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(filled ? .white : tint)
            .padding(.vertical, 9).padding(.horizontal, 18)
            .background(filled ? AnyShapeStyle(LinearGradient.neonH) : AnyShapeStyle(Color.panel), in: Capsule())
            .overlay(Capsule().stroke(filled ? Color.clear : tint.opacity(0.5), lineWidth: 1))
    }

    private var stateValue: String {
        switch badge.state {
        case .lit:    return badge.unlockedAt?.formatted(Self.dateFormat) ?? "已获得".localized
        case .prog:   return badge.progressText ?? "进行中".localized
        case .locked: return "未解锁".localized
        }
    }
    private var stateLabel: String {
        switch badge.state {
        case .lit: return "获得时间".localized; case .prog: return "当前进度".localized; case .locked: return "状态".localized
        }
    }

    private func statBox(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
            Text(l.localized).font(.system(size: 9)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 13).panelCard(13)
    }
}

// MARK: - 解锁庆祝

struct UnlockCelebration: View {
    let badges: [Badge]
    let onDismiss: () -> Void

    init(badge: Badge, onDismiss: @escaping () -> Void) {
        self.badges = [badge]; self.onDismiss = onDismiss
    }
    init(badges: [Badge], onDismiss: @escaping () -> Void) {
        self.badges = badges; self.onDismiss = onDismiss
    }

    @State private var shown = false
    @State private var shareImage: Image?

    private var isMulti: Bool { badges.count > 1 }
    /// 用首枚的颜色驱动背景/粒子（多枚时取一个主色即可）。
    private var accent: Color { badges.first?.color ?? .nPink }

    var body: some View {
        ZStack {
            // 背景遮罩调暗、收紧光晕，避免与下层内容混在一起
            RadialGradient(colors: [accent.opacity(0.22), Color.bg.opacity(0.985)],
                           center: .center, startRadius: 10, endRadius: 300)
                .ignoresSafeArea()
            Color.bg.opacity(0.55).ignoresSafeArea()
            // 粒子迸发（在徽章后方扩散）
            UnlockBurst(color: accent)
                .frame(width: 360, height: 360)
                .opacity(shown ? 0.85 : 0)

            content
                .padding(.vertical, 36).padding(.horizontal, 30)
                // 内容卡片底：把徽章与文字托在一张半透明卡上，与粒子背景分层
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.bg.opacity(0.72))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(accent.opacity(0.45), lineWidth: 1))
                        .shadow(color: accent.opacity(0.35), radius: 30, y: 8)
                )
                .padding(.horizontal, isMulti ? 28 : 40)
                .scaleEffect(shown ? 1 : 0.5).opacity(shown ? 1 : 0)

            VStack {
                Spacer()
                Text("点击任意处继续").font(.system(size: 11)).foregroundStyle(Color.faint).padding(.bottom, 42)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { shown = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if !isMulti, let b = badges.first {
                shareImage = ShareRender.image(BadgeShareCard(badge: b))
            }
        }
    }

    @ViewBuilder private var content: some View {
        if isMulti { multiContent } else { singleContent }
    }

    // 单枚：大图 + 名称 + 稀有度 + 分享（保持原样）
    @ViewBuilder private var singleContent: some View {
        let badge = badges[0]
        VStack(spacing: 9) {
            HolographicBadge(badge: badge, size: 132).padding(.bottom, 16)
            Text("成就解锁 · UNLOCKED").font(.system(size: 12, weight: .bold)).tracking(3)
                .foregroundStyle(Color.nCyan)
            Text(badge.name.localized).font(Typo.serif(33)).foregroundStyle(Color.text)
            Text("\(badge.rarity.tierName.localized) · \(badge.rarity.rawValue.uppercased())")
                .font(.system(size: 11.5, weight: .heavy)).tracking(1.8)
                .foregroundStyle(badge.color)
            if let shareImage {
                ShareLink(item: shareImage,
                          preview: SharePreview(badge.name.localized, image: shareImage)) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.vertical, 11).padding(.horizontal, 26)
                        .background(LinearGradient.neonH, in: Capsule())
                }
                .padding(.top, 18)
            }
        }
    }

    // 多枚：汇总「点亮了 N 个徽章」+ 徽章拼在一起，不展示具体名字
    @ViewBuilder private var multiContent: some View {
        let cols = min(badges.count, 3)
        let size: CGFloat = badges.count <= 4 ? 92 : (badges.count <= 6 ? 78 : 66)
        let grid = Array(repeating: GridItem(.flexible(), spacing: 12), count: cols)
        VStack(spacing: 14) {
            Text("成就解锁 · UNLOCKED").font(.system(size: 12, weight: .bold)).tracking(3)
                .foregroundStyle(Color.nCyan)
            LazyVGrid(columns: grid, spacing: 14) {
                ForEach(badges) { b in HexBadge(badge: b, size: size) }
            }
            Text("点亮了 \(badges.count) 个徽章")
                .font(Typo.serif(27)).foregroundStyle(Color.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 320)
    }
}
