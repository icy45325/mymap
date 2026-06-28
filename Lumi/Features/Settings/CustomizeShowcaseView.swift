import SwiftUI

/// 个性化展示台：把可定制的东西（小组件 / 护照风格）摘出来「打组」成可视画廊。
/// 小组件可看小 + 中两种尺寸并「添加到桌面」（图文指引）；护照风格点一下即应用。
/// 作为设置页的下钻页（外层已有 NavigationStack）。
struct CustomizeShowcaseView: View {

    @AppStorage("lumi.passport.style") private var passportStyle: String = PassportStyle.classic.rawValue
    @State private var widgetPage = 0
    @State private var showGuide = false

    private let widgetNames: [LocalizedStringKey] = ["点亮战绩", "去过的国旗", "去年今日"]
    private var currentWidgetName: LocalizedStringKey { widgetNames[min(widgetPage, widgetNames.count - 1)] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                widgetSection
                passportSection
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("个性化")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showGuide) { WidgetAddGuideSheet(widgetName: currentWidgetName) }
    }

    // MARK: 小组件展示（轮播：每个含小 + 中两种尺寸）

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("小组件 Widgets", "把旅行进度放上主屏 / 锁屏")
            TabView(selection: $widgetPage) {
                widgetShowcaseCard(name: "点亮战绩", desc: "主屏显示已点亮国家数与全球占比",
                                   small: { statsWidgetTile }, medium: { statsWidgetMediumTile }).tag(0)
                widgetShowcaseCard(name: "去过的国旗", desc: "去过国家的国旗集合，一眼看遍",
                                   small: { flagsWidgetTile }, medium: { flagsWidgetMediumTile }).tag(1)
                widgetShowcaseCard(name: "去年今日", desc: "回看往年此刻你在的地方",
                                   small: { onThisDayWidgetTile }, medium: { onThisDayWidgetMediumTile }).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 430)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(i == widgetPage ? Color.nPink : Color.line)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)

            Button { showGuide = true } label: {
                Label("添加到桌面", systemImage: "plus.app.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LinearGradient.neonH, in: Capsule())
            }
            .padding(.top, 4)
        }
    }

    private func widgetShowcaseCard<S: View, M: View>(name: LocalizedStringKey, desc: LocalizedStringKey,
                                                      @ViewBuilder small: () -> S,
                                                      @ViewBuilder medium: () -> M) -> some View {
        VStack(spacing: 14) {
            small()
                .frame(width: 150, height: 150)
                .background(widgetTileBG, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            medium()
                .frame(width: 300, height: 142)
                .background(widgetTileBG, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            VStack(spacing: 3) {
                Text(name).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.text)
                Text(desc).font(.system(size: 12)).foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RadialGradient(colors: [Color.nPurple.opacity(0.16), .clear],
                           center: .top, startRadius: 8, endRadius: 260)
        )
    }

    private var widgetTileBG: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x12101F), Color(hex: 0x0A0A16)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: 小尺寸示意（方块）

    private var statsWidgetTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            widgetTileHeader("点亮战绩")
            Spacer(minLength: 0)
            Text("12").font(Typo.serif(46)).foregroundStyle(Color.nOrange)
            Text("个国家 · 全球 5%").font(.system(size: 11)).foregroundStyle(Color.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private var flagsWidgetTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetTileHeader("去过的国旗")
            Spacer(minLength: 0)
            Text(["AE","CN","JP","FR","GB","IT","US","TH"].map { CountryInfo.flag(for: $0) }.joined())
                .font(.system(size: 22)).lineLimit(2).minimumScaleFactor(0.7)
            Text("已点亮 12 国").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private var onThisDayWidgetTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetTileHeader("去年今日")
            Spacer(minLength: 0)
            Text("✈️").font(.system(size: 30))
            Text("去年此刻你在 东京 ✦").font(.system(size: 11)).foregroundStyle(Color.text).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    // MARK: 中尺寸示意（一横条，2:1）

    private var statsWidgetMediumTile: some View {
        HStack(spacing: 14) {
            dotMatrix
            VStack(alignment: .leading, spacing: 3) {
                widgetTileHeader("点亮战绩")
                Text("12").font(Typo.serif(40)).foregroundStyle(Color.nOrange)
                Text("个国家 · 全球 5%").font(.system(size: 11)).foregroundStyle(Color.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    /// 点阵地球的简化示意（5×6 小点，部分点亮）。
    private var dotMatrix: some View {
        let lit: Set<Int> = [1,2,5,6,7,8,11,12,13,16,17,22,23,26]
        return VStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { c in
                        Circle()
                            .fill(lit.contains(r * 6 + c) ? Color.nOrange : Color.white.opacity(0.12))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }

    private var flagsWidgetMediumTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetTileHeader("去过的国旗")
            Text(["AE","CN","JP","FR","GB","IT","US","TH","TR","EG","GR","ES","PT"]
                .map { CountryInfo.flag(for: $0) }.joined())
                .font(.system(size: 20)).lineLimit(2).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text("已点亮 12 国").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private var onThisDayWidgetMediumTile: some View {
        VStack(alignment: .leading, spacing: 5) {
            widgetTileHeader("去年今日")
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text("🗼").font(.system(size: 26))
                Text("东京").font(Typo.serif(26)).foregroundStyle(Color.text)
            }
            Text("去年此刻你在 东京 ✦").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.nOrange)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private func widgetTileHeader(_ s: LocalizedStringKey) -> some View {
        (Text("LUMI · ").font(.system(size: 8.5, weight: .bold)).tracking(1)
            + Text(s).font(.system(size: 8.5, weight: .bold)).tracking(1))
            .foregroundStyle(Color.muted)
    }

    // MARK: 护照风格画廊（迷你护照封面占位图）

    private var passportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("护照风格", "护照本封面与内页风格")
            HStack(spacing: 16) {
                ForEach(PassportStyle.allCases) { s in
                    passportCard(s, active: passportStyle == s.rawValue)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func passportCard(_ style: PassportStyle, active: Bool) -> some View {
        Button { passportStyle = style.rawValue } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    passportCoverThumb(style)
                        .frame(width: 96, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(active ? Color.nPink : Color.white.opacity(0.1), lineWidth: active ? 2 : 1))
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
                    if active {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18)).foregroundStyle(Color.nPink)
                            .background(Circle().fill(Color.bg).padding(2))
                            .padding(5)
                    }
                }
                Text(style.label).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Color.text : Color.muted)
            }
            .padding(8)
            .background(active ? Color.white.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? Color.white.opacity(0.16) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 迷你护照封面（与真实 coverPage 同调，不依赖私有 NationTheme）。
    @ViewBuilder
    private func passportCoverThumb(_ style: PassportStyle) -> some View {
        let starlit = style == .starlit
        let ink: Color = starlit ? .white : Color(hex: 0xC9A24B)        // 星夜白 / 拟真金箔
        let emblemStroke: Color = starlit ? Color(hex: 0xFFC9E0).opacity(0.85) : Color(hex: 0xC9A24B)
        ZStack {
            LinearGradient(colors: starlit ? [Color(hex: 0x241349), Color(hex: 0x0C0A1E)]
                                           : [Color(hex: 0x1E4D34), Color(hex: 0x0E1F18)],
                           startPoint: .top, endPoint: .bottom)
            if starlit {
                RadialGradient(colors: [Color(hex: 0xC77DFF).opacity(0.28), .clear],
                               center: .top, startRadius: 0, endRadius: 90)
            }
            VStack(spacing: 0) {
                Text(verbatim: "LUMI").font(Typo.serif(7)).tracking(2).foregroundStyle(ink.opacity(0.85))
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(emblemStroke, lineWidth: 1.2).frame(width: 44, height: 44)
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 20)).foregroundStyle(ink)
                }
                .shadow(color: starlit ? Color(hex: 0xFF6EAA).opacity(0.45) : .clear, radius: 8)
                Spacer(minLength: 0)
                VStack(spacing: 3) {
                    Group {
                        if starlit {
                            Text(verbatim: "PASSPORT").foregroundStyle(LinearGradient.neonH)
                        } else {
                            Text(verbatim: "PASSPORT").foregroundStyle(ink)
                        }
                    }
                    .font(Typo.serif(10)).fontWeight(.semibold).tracking(2)
                    Text(verbatim: "LUMI").font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.9))
                        .frame(width: 26, height: 14)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(ink.opacity(0.5), lineWidth: 0.8))
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 10)
        }
    }

    // MARK: 通用

    private func sectionHeader(_ title: LocalizedStringKey, _ sub: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.text)
            Text(sub).font(.system(size: 12)).foregroundStyle(Color.muted)
        }
    }
}

// MARK: - 添加小组件到桌面指引

/// 「添加到桌面」图文步骤（iOS 无 API 直接添加小组件，引导用户手动添加）。
private struct WidgetAddGuideSheet: View {
    let widgetName: LocalizedStringKey
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, LocalizedStringKey)] = [
        ("hand.tap.fill", "长按主屏空白处，进入编辑状态"),
        ("plus.circle.fill", "点左上角的「+」号"),
        ("magnifyingglass", "搜索「Lumi」"),
        ("square.grid.2x2.fill", "选择小组件与尺寸（小 / 中），点「添加小组件」"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("添加到桌面").font(Typo.serif(26)).foregroundStyle(Color.text)
                        Text(widgetName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nPink)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 12) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(LinearGradient.neonH).frame(width: 28, height: 28)
                                    Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                }
                                Image(systemName: step.0).font(.system(size: 16)).foregroundStyle(Color.nPink)
                                    .frame(width: 24)
                                Text(step.1).font(.system(size: 14)).foregroundStyle(Color.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(12).panelCard(14)
                        }
                    }

                    Text("小组件会跟随系统语言显示")
                        .font(.system(size: 11)).foregroundStyle(Color.muted)

                    Button { dismiss() } label: {
                        Text("知道了").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient.neonH, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
