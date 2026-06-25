import SwiftUI
import SwiftData

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
                    ringSummary
                    if let f = featuredBadge { showcase(f) }
                    SegmentBar(items: segmentItems, selection: $categoryFilter)
                    honeycomb
                    if let n = board.nextUp { nextUpSection(n) }
                    conquestSection
                    Color.clear.frame(height: 20)
                }
                .padding(.top, 16)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .onAppear { Analytics.log(.statsViewed(totalLit: stats.countries, percent: Int(stats.worldPercent.rounded()))) }
        .sheet(item: $selectedBadge) { BadgeSheet(badge: $0) }
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
            VStack(alignment: .leading, spacing: 9) {
                Text("徽章收藏").font(Typo.serif(21))
                HStack(spacing: 8) {
                    kv("\(stats.countries)", "已点亮国")
                    kv("\(stats.cities)", "城市")
                }
            }
            Spacer()
        }
        .padding(.horizontal, 26)
    }

    private func kv(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.text)
            Text(l.localized).font(.system(size: 9)).foregroundStyle(Color.muted)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard(12)
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

    // MARK: - 蜂巢

    private var honeycomb: some View {
        let rows = honeycombRows
        let stagger: CGFloat = 30                     // 交替行错位量（仅左右错，绝不上下叠）
        return VStack(spacing: 16) {                  // 正间距：行与行不再遮挡
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 12) {
                    ForEach(row) { b in honeyCell(b) }
                }
                .offset(x: idx.isMultiple(of: 2) ? -stagger / 2 : stagger / 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    /// 蜂巢单元：徽章 + 名称。点击任意处看「是什么 / 怎么得到」。
    private func honeyCell(_ b: Badge) -> some View {
        VStack(spacing: 5) {
            HexBadge(badge: b, size: 58, dimmed: !matches(b))
            Text(b.name.localized)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(matches(b) ? Color.muted : Color.faint)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: 66)
        }
        .frame(width: 66)
        .contentShape(Rectangle())
        .onTapGesture { selectedBadge = b }
    }

    /// 把徽章按 4 / 3 交替切成蜂巢行。
    private var honeycombRows: [[Badge]] {
        var rows: [[Badge]] = []
        var i = 0
        let all = board.badges
        let pattern = [4, 3]
        var p = 0
        while i < all.count {
            let n = pattern[p % pattern.count]
            rows.append(Array(all[i..<min(i + n, all.count)]))
            i += n; p += 1
        }
        return rows
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
            Button { celebrate = b } label: {
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

    @AppStorage("lumi.featuredBadgeID") private var pinnedID: String = ""
    private var isPinned: Bool { pinnedID == badge.id }

    private static let dateFormat: Date.FormatStyle = .dateTime.year().month().day()

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.line).frame(width: 40, height: 4).padding(.top, 11).padding(.bottom, 18)
            HexBadge(badge: badge, size: 96)
            Text(badge.name.localized).font(Typo.serif(24)).foregroundStyle(Color.text).padding(.top, 16)
            Text("\(badge.rarity.tierName.localized) · \(badge.rarity.rawValue.uppercased())")
                .font(.system(size: 10.5, weight: .heavy)).tracking(1.6)
                .foregroundStyle(badge.rarity.color).padding(.top, 7)

            // 怎么得到：解锁条件文案（+ 进行中进度）
            VStack(spacing: 8) {
                Text((badge.state == .lit ? "已解锁" : "解锁条件").localized)
                    .font(.system(size: 10, weight: .bold)).tracking(1.5)
                    .foregroundStyle(badge.state == .lit ? Color.grn : Color.nCyan)
                Text(badge.desc.localized).font(.system(size: 13)).foregroundStyle(Color(hex: 0xC9C2D6))
                    .multilineTextAlignment(.center)
                if badge.state == .prog, let p = badge.progress {
                    NeonBar(fraction: p, height: 8).frame(height: 8)
                    Text(badge.progressText ?? "").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
            }
            .padding(.top, 13).padding(.horizontal, 26)

            HStack(spacing: 10) {
                statBox(badge.ownership, "全球持有率")
                statBox(stateValue, stateLabel)
            }
            .padding(.top, 18).padding(.horizontal, 26)

            // 置顶控制：仅已解锁可钉选；可随时取消
            if badge.state == .lit {
                Button { pinnedID = isPinned ? "none" : badge.id } label: {
                    Label((isPinned ? "取消置顶" : "设为置顶展示").localized,
                          systemImage: isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isPinned ? Color.nOrange : .white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(isPinned
                            ? AnyShapeStyle(Color.panel)
                            : AnyShapeStyle(LinearGradient.neonH), in: Capsule())
                        .overlay(Capsule().stroke(isPinned ? Color.nOrange.opacity(0.5) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 16).padding(.horizontal, 26)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x0F0F1B).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
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

private struct UnlockCelebration: View {
    let badge: Badge
    let onDismiss: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.nPurple.opacity(0.32), Color.bg.opacity(0.95)],
                           center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
            VStack(spacing: 9) {
                HexBadge(badge: badge, size: 122)
                    .shadow(color: badge.rarity.color.opacity(0.7), radius: 24)
                    .padding(.bottom, 16)
                Text("成就解锁 · UNLOCKED").font(.system(size: 12, weight: .bold)).tracking(3)
                    .foregroundStyle(Color.nCyan)
                Text(badge.name.localized).font(Typo.serif(33)).foregroundStyle(Color.text)
                Text("\(badge.rarity.tierName.localized) · \(badge.rarity.rawValue.uppercased())")
                    .font(.system(size: 11.5, weight: .heavy)).tracking(1.8)
                    .foregroundStyle(badge.rarity.color)
            }
            .scaleEffect(shown ? 1 : 0.5).opacity(shown ? 1 : 0)
            VStack {
                Spacer()
                Text("点击任意处继续").font(.system(size: 11)).foregroundStyle(Color.faint).padding(.bottom, 42)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { shown = true } }
    }
}
