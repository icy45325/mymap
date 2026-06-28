import SwiftUI

/// 个性化展示台：把可定制的东西（小组件 / 明信片样式 / 邮票 / 护照风格）摘出来「打组」成可视画廊，
/// 滑动浏览，点一下即应用（写入对应 `@AppStorage` 默认值）。
/// 作为设置页的下钻页（外层已有 NavigationStack）。
struct CustomizeShowcaseView: View {

    @AppStorage("lumi.postcard.style") private var postcardStyle: String = PostcardStyle.vintage.rawValue
    @AppStorage("lumi.postcard.stamp") private var postcardStamp: String = PostcardStamp.air.rawValue
    @AppStorage("lumi.passport.style") private var passportStyle: String = PassportStyle.classic.rawValue
    @State private var widgetPage = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                widgetSection
                postcardStyleSection
                stampSection
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
    }

    // MARK: 小组件展示（轮播）

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("小组件 Widgets", "把旅行进度放上主屏 / 锁屏")
            TabView(selection: $widgetPage) {
                widgetShowcaseCard(name: "点亮战绩", desc: "主屏显示已点亮国家数与全球占比") {
                    statsWidgetTile
                }.tag(0)
                widgetShowcaseCard(name: "去过的国旗", desc: "去过国家的国旗集合，一眼看遍") {
                    flagsWidgetTile
                }.tag(1)
                widgetShowcaseCard(name: "去年今日", desc: "回看往年此刻你在的地方") {
                    onThisDayWidgetTile
                }.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(i == widgetPage ? Color.nPink : Color.line)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)

            Text("添加方式：长按桌面空白处 → 左上角「+」→ 搜索 “Lumi” → 选择小组件。小组件文案跟随系统语言。")
                .font(.system(size: 11)).foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func widgetShowcaseCard<C: View>(name: LocalizedStringKey, desc: LocalizedStringKey,
                                             @ViewBuilder _ tile: () -> C) -> some View {
        VStack(spacing: 14) {
            tile()
                .frame(width: 168, height: 168)
                .background(widgetTileBG, in: RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            VStack(spacing: 3) {
                Text(name).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.text)
                Text(desc).font(.system(size: 12)).foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RadialGradient(colors: [Color.nPurple.opacity(0.16), .clear],
                           center: .top, startRadius: 8, endRadius: 240)
        )
    }

    private var widgetTileBG: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x12101F), Color(hex: 0x0A0A16)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // 三个小组件的迷你示意（与真实 widget 同调）
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

    private func widgetTileHeader(_ s: LocalizedStringKey) -> some View {
        (Text("LUMI · ").font(.system(size: 8.5, weight: .bold)).tracking(1)
            + Text(s).font(.system(size: 8.5, weight: .bold)).tracking(1))
            .foregroundStyle(Color.muted)
    }

    // MARK: 明信片样式画廊

    private var postcardStyleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("明信片样式", "选一个默认卡面，分享时即用")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PostcardStyle.allCases) { s in
                        let active = postcardStyle == s.rawValue
                        Button { postcardStyle = s.rawValue } label: {
                            swatchCard(active: active, label: s.label) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: s.thumb, startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: 邮票画廊

    private var stampSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("邮票", "默认邮票贴图")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PostcardStamp.allCases) { p in
                        let active = postcardStamp == p.rawValue
                        Button { postcardStamp = p.rawValue } label: {
                            swatchCard(active: active, label: p.label) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Color.panel)
                                    PostcardStampView(stamp: p).frame(width: 44, height: 52)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: 护照风格画廊

    private var passportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("护照风格", "护照本封面与内页风格")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PassportStyle.allCases) { s in
                        let active = passportStyle == s.rawValue
                        Button { passportStyle = s.rawValue } label: {
                            swatchCard(active: active, label: s.label) {
                                RoundedRectangle(cornerRadius: 10).fill(passportThumb(s))
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func passportThumb(_ s: PassportStyle) -> LinearGradient {
        s == .classic
            ? LinearGradient(colors: [Color(hex: 0x1B3A2E), Color(hex: 0x0E1F18)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: 0x241349), Color(hex: 0x0C0A1E)], startPoint: .top, endPoint: .bottom)
    }

    // MARK: 通用

    private func sectionHeader(_ title: LocalizedStringKey, _ sub: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.text)
            Text(sub).font(.system(size: 12)).foregroundStyle(Color.muted)
        }
    }

    /// 选择型样式卡：缩略图 + 名称 + 选中描边 / 勾。
    private func swatchCard<C: View>(active: Bool, label: LocalizedStringKey,
                                     @ViewBuilder _ thumb: () -> C) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumb()
                    .frame(width: 104, height: 72)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(active ? Color.nPink : Color.white.opacity(0.1), lineWidth: active ? 2 : 1))
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(Color.nPink)
                        .background(Circle().fill(Color.bg).padding(2))
                        .padding(5)
                }
            }
            Text(label).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.text : Color.muted)
        }
        .padding(8)
        .background(active ? Color.white.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? Color.white.opacity(0.16) : .clear, lineWidth: 1))
    }
}
