import SwiftUI
import SwiftData
import UIKit

/// 写实护照本（复刻设计稿）：按**个人信息**的国籍生成封面 / 资料页 / 入境章，可翻页。
/// 两种风格：拟真(classic) / 星夜(starlit)。未设置个人信息时显示空状态引导去填写。
/// 语言跟随系统（沿用现有本地化）；国籍来自个人资料而非页面切换。
struct PassportView: View {

    @Query(sort: \Footprint.visitedAt, order: .forward) private var footprints: [Footprint]

    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @AppStorage("lumi.profile.nationality") private var nationality: String = ""
    @AppStorage("lumi.profile.avatarID") private var avatarID: String = ""
    @AppStorage("lumi.passport.style") private var styleRaw: String = PassportStyle.classic.rawValue

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var detail: PassportStamp?
    @State private var showProfileEdit = false
    @State private var stampPop = false

    private var style: PassportStyle { PassportStyle(rawValue: styleRaw) ?? .classic }
    private var nation: NationTheme { NationTheme.resolve(nationality) }
    private var theme: PageTheme { PageTheme.make(style) }

    private static let df: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()

    // MARK: - 入境章数据（每个去过的国家一枚，取最早到访 + 一座城）

    private static let inks: [UInt32] = [0x1F6B46, 0x23508F, 0x5A2F7A, 0x9C2B2B, 0x2A2A2A, 0x1F6B6B]
    private static let shapes: [StampShape] = [.circle, .rect, .oval, .circle]

    private var stamps: [PassportStamp] {
        var seen = Set<String>()
        var out: [PassportStamp] = []
        for fp in footprints where !fp.isReceived {  // 已按 visitedAt 升序 → 首次出现即最早；收到的卡不盖入境章
            guard let cc = fp.countryCode, !cc.isEmpty, !seen.contains(cc) else { continue }
            seen.insert(cc)
            let i = out.count
            let country = CountryInfo.localizedName(for: cc) ?? cc
            out.append(PassportStamp(
                id: cc,
                country: country,
                port: (fp.cityName ?? country).uppercased(),
                date: fp.visitedAt.formatted(Self.df).uppercased(),
                place: fp.cityName.map { "\($0) · \(country)" } ?? country,
                code3: NationTheme.iso3(cc),
                inkHex: Self.inks[i % Self.inks.count],
                shape: Self.shapes[i % Self.shapes.count],
                means: PostcardStamp(rawValue: fp.entryMeans) ?? .air))
        }
        return out
    }
    private var stampPagesOrEmpty: [[PassportStamp]] {
        let chunks = stride(from: 0, to: stamps.count, by: 4).map { Array(stamps[$0..<min($0 + 4, stamps.count)]) }
        return chunks.isEmpty ? [[]] : chunks
    }
    private var pageCount: Int { 2 + stampPagesOrEmpty.count }

    // MARK: - body

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x15101F), Color(hex: 0x06040B)],
                           center: .top, startRadius: 0, endRadius: 620)
                .ignoresSafeArea()

            if nationality.isEmpty { emptyState }
            else { passport }

            if let d = detail { detailOverlay(d) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)   // 二级页：隐藏底部 Tab，整页沉浸
        .overlay(alignment: .topLeading) { backButton }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showProfileEdit) { ProfileEditView() }
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.backward").font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .padding(.leading, 16).padding(.top, 8)
    }

    // MARK: - 空状态（未设置个人信息）

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color(hex: 0xC9A24B).opacity(0.5), lineWidth: 1.5).frame(width: 96, height: 96)
                Image(systemName: "person.text.rectangle").font(.system(size: 38))
                    .foregroundStyle(Color(hex: 0xC9A24B))
            }
            Text("还没有个人信息").font(Typo.serif(24)).foregroundStyle(.white)
            Text("设置姓名和国籍，生成你的专属护照本")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 50)
            Button { showProfileEdit = true } label: {
                Label("添加个人信息", systemImage: "plus")
                    .font(.headline).padding(.vertical, 13).padding(.horizontal, 24)
                    .background(LinearGradient.neonH, in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(color: Color.nPink.opacity(0.4), radius: 12)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 护照主体

    /// 整页护照：去掉底部翻页条，书本占满可用空间，顶部留白最小。
    private var passport: some View {
        book
            .padding(.top, 44)    // 仅给左上返回按钮让位，尽量少留白
            .padding(.bottom, 8)
    }

    // MARK: - 翻页书（左右滑动，整页放大）

    private var book: some View {
        TabView(selection: $page) {
            coverPage.tag(0)
            bioPage.tag(1)
            ForEach(Array(stampPagesOrEmpty.enumerated()), id: \.offset) { i, pageStamps in
                stampPage(pageStamps, pageNo: i + 2).tag(i + 2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(0.7, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 28, x: 0, y: 22)
        .padding(.horizontal, 14)
    }

    // MARK: - 页 0：封面

    private var coverPage: some View {
        ZStack {
            nation.coverBackground(style)
            if style == .starlit {
                RadialGradient(colors: [Color(hex: 0xC77DFF).opacity(0.24), .clear],
                               center: .top, startRadius: 0, endRadius: 200)
            }
            VStack(spacing: 0) {
                VStack(spacing: 5) {
                    Text(nation.primary)
                        .font(Typo.serif(nation.nameSize)).fontWeight(.semibold)
                        .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.7)
                        .foregroundStyle(nation.coverInk(style))
                    if !nation.secondary.isEmpty {
                        Text(nation.secondary)
                            .font(Typo.serif(9.5)).tracking(1.4)
                            .foregroundStyle(nation.coverInk(style).opacity(0.7))
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(nation.emblemStroke(style), lineWidth: style == .classic ? 2 : 1.5)
                        .frame(width: 100, height: 100)
                    Image(systemName: nation.emblem).font(.system(size: 44))
                        .foregroundStyle(nation.coverInk(style))
                }
                .shadow(color: style == .starlit ? Color(hex: 0xFF6EAA).opacity(0.45) : .clear, radius: 14)
                Spacer()
                VStack(spacing: 4) {
                    if !nation.native.isEmpty {
                        Text(nation.native).font(Typo.serif(15)).tracking(5)
                            .foregroundStyle(nation.coverInk(style))
                    }
                    passportWordmark
                    Text(nation.code3)
                        .font(.system(size: 9, weight: .semibold)).tracking(0.5)
                        .frame(width: 30, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(nation.coverInk(style).opacity(0.5), lineWidth: 1))
                        .foregroundStyle(nation.coverInk(style))
                        .padding(.top, 10)
                }
            }
            .padding(.vertical, 38).padding(.horizontal, 26)
        }
    }

    @ViewBuilder private var passportWordmark: some View {
        if style == .starlit {
            Text("PASSPORT").font(Typo.serif(20)).fontWeight(.semibold).tracking(7)
                .foregroundStyle(LinearGradient.neonH)
        } else {
            Text("PASSPORT").font(Typo.serif(20)).fontWeight(.semibold).tracking(7)
                .foregroundStyle(nation.coverInk(style))
        }
    }

    // MARK: - 页 1：资料页

    private var bioPage: some View {
        ZStack {
            theme.pageBackground
            patternOverlay
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("个人资料").font(Typo.serif(14)).tracking(1.5).foregroundStyle(theme.soft)
                    Spacer()
                    Text(nation.code3).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.soft)
                }
                .padding(.bottom, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.line).frame(height: 1) }

                HStack(alignment: .top, spacing: 16) {
                    photoBox
                    VStack(alignment: .leading, spacing: 13) {
                        bioField("姓名", holderName.isEmpty ? String(localized: "旅行者") : holderName)
                        bioField("国籍", "\(CountryInfo.localizedName(for: nationality) ?? nationality)  \(nation.code3)")
                        bioField("签发", "LUMI")
                    }
                }
                .padding(.top, 16)

                summaryBox.padding(.top, 16)

                Spacer(minLength: 12)

                // MRZ 机读码：置于资料页最底部
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle().fill(theme.line).frame(height: 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mrz1).lineLimit(1)
                        Text(mrz2).lineLimit(1)
                    }
                    .font(.system(size: 9.5, design: .monospaced)).tracking(1)
                    .foregroundStyle(theme.ink.opacity(0.78))
                }
            }
            .padding(16)
        }
    }

    private var photoBox: some View {
        Group {
            if avatarID.isEmpty {
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x6B4D8A), Color(hex: 0x3A2B52)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack {
                        Text(String(holderName.prefix(1))).font(Typo.serif(50))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("LUMI ID").font(.system(size: 8, weight: .semibold)).tracking(1)
                            .foregroundStyle(.white.opacity(0.55)).padding(.bottom, 6)
                    }
                    .padding(.top, 10)
                }
            } else {
                AssetImage(assetID: avatarID, targetSize: CGSize(width: 280, height: 350))
            }
        }
        .frame(width: 150, height: 188)   // 放大约占资料页 1/4
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.line, lineWidth: 1))
    }

    private func bioField(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
                .foregroundStyle(theme.soft).textCase(.uppercase)
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private var summaryBox: some View {
        let s = LumiStats(footprints: footprints)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(s.countries)").font(Typo.serif(34)).fontWeight(.semibold).foregroundStyle(nation.accent(style))
                Text("个国家已点亮").font(.system(size: 13)).foregroundStyle(theme.soft)
            }
            FlowRow(spacing: 5) {
                ForEach(stamps.prefix(12)) { st in
                    Text(st.code3)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced)).tracking(0.5)
                        .foregroundStyle(nation.accent(style))
                        .padding(.vertical, 3).padding(.horizontal, 6)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(nation.accent(style).opacity(0.4), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)   // 国家计数横向拉通
        .padding(13)
        .background(theme.summaryBg, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.line, lineWidth: 1))
    }

    private var mrz1: String {
        let name = (holderName.isEmpty ? "TRAVELER" : holderName).uppercased()
            .filter { $0.isASCII && $0.isLetter }
        return String(("P<\(nation.code3)\(name)<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<").prefix(36))
    }
    private var mrz2: String {
        String(("LM\(String(format: "%07d", footprints.count))\(nation.code3)<<<<<<<<<<<<<<<<<00").prefix(36))
    }

    // MARK: - 页 2+：入境章

    private static let posA: [(CGFloat, CGFloat, Double)] = [(0.07, 0.06, -7), (0.10, 0.50, 6), (0.46, 0.10, -3), (0.51, 0.46, 10)]
    private static let posB: [(CGFloat, CGFloat, Double)] = [(0.08, 0.46, 5), (0.13, 0.05, -8), (0.50, 0.43, -5), (0.54, 0.07, 9)]

    private func stampPage(_ pageStamps: [PassportStamp], pageNo: Int) -> some View {
        ZStack {
            theme.pageBackground
            patternOverlay
            Text("VISAS · \(String(format: "%02d", pageNo))")
                .font(.system(size: 9, design: .monospaced)).tracking(1).foregroundStyle(theme.soft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12).padding(.trailing, 14)

            if pageStamps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "airplane.departure").font(.system(size: 38)).foregroundStyle(theme.soft)
                    Text("护照还是空的").font(Typo.serif(19)).foregroundStyle(theme.ink.opacity(0.8))
                    Text("去点亮第一个国家，盖下第一枚入境章")
                        .font(.system(size: 11)).foregroundStyle(theme.soft)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                }
            } else {
                GeometryReader { geo in
                    let pos = (pageNo % 2 == 0) ? Self.posA : Self.posB
                    ForEach(Array(pageStamps.enumerated()), id: \.element.id) { i, st in
                        let p = pos[i % pos.count]
                        Button { openDetail(st) } label: { stampRing(st, big: false) }
                            .buttonStyle(.plain)
                            .rotationEffect(.degrees(p.2))
                            .position(x: geo.size.width * (p.1 + 0.18), y: geo.size.height * (p.0 + 0.2))
                    }
                }
            }
        }
    }

    // MARK: - 入境章图样

    @ViewBuilder
    private func stampRing(_ st: PassportStamp, big: Bool) -> some View {
        let ink = style == .starlit ? Color(hex: st.inkHex).lightened(0.55) : Color(hex: st.inkHex)
        let scale: CGFloat = big ? 1.55 : 1
        let content = VStack(spacing: 2) {
            Text(st.country).font(Typo.serif(big ? 12 : 8)).fontWeight(.semibold).tracking(1)
                .lineLimit(1).minimumScaleFactor(0.6)
            Image(systemName: st.means.motif).font(.system(size: big ? 18 : 13)).rotationEffect(.degrees(-8))
            Text("ADMITTED").font(Typo.serif(big ? 9 : 6.5)).fontWeight(.semibold).tracking(1.5)
            Rectangle().fill(ink.opacity(0.55)).frame(width: big ? 90 : 52, height: 1)
            Text(st.port).font(Typo.serif(big ? 16 : 10)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.6)
            Text(st.date).font(.system(size: big ? 12 : 8, design: .monospaced))
        }
        .foregroundStyle(ink)
        .padding(big ? 14 : 9)
        .frame(width: st.shape.size(big).width, height: st.shape.size(big).height)
        .background(stampShapeFill(st.shape, ink: ink))
        .overlay(stampShapeStroke(st.shape, ink: ink))
        .opacity(style == .starlit ? 1 : 0.85)
        .shadow(color: style == .starlit ? ink.opacity(0.4) : .clear, radius: 8)

        content.scaleEffect(scale)
    }

    @ViewBuilder
    private func stampShapeStroke(_ shape: StampShape, ink: Color) -> some View {
        let w: CGFloat = style == .starlit ? 2 : 2.5
        switch shape {
        case .circle: Circle().stroke(ink, lineWidth: w)
        case .oval:   Ellipse().stroke(ink, lineWidth: w)
        case .rect:   RoundedRectangle(cornerRadius: 6).stroke(ink, lineWidth: w)
        }
    }
    @ViewBuilder
    private func stampShapeFill(_ shape: StampShape, ink: Color) -> some View {
        // starlit 微微发光底；classic 透明（叠纸感）
        let fill = style == .starlit ? ink.opacity(0.06) : Color.clear
        switch shape {
        case .circle: Circle().fill(fill)
        case .oval:   Ellipse().fill(fill)
        case .rect:   RoundedRectangle(cornerRadius: 6).fill(fill)
        }
    }

    @ViewBuilder private var patternOverlay: some View {
        switch style {
        case .classic:
            // 斜纹纸纹
            Rectangle().fill(Color(hex: 0x3A2F20).opacity(0.04))
                .mask(StripePattern().stroke(Color.black, lineWidth: 1))
                .allowsHitTesting(false)
        case .starlit:
            Color.clear
        }
    }

    // MARK: - 入境章详情浮层

    private func openDetail(_ st: PassportStamp) {
        stampPop = false
        detail = st
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { stampPop = true }
    }

    private func detailOverlay(_ st: PassportStamp) -> some View {
        let ink = style == .starlit ? Color(hex: st.inkHex).lightened(0.5) : Color(hex: st.inkHex)
        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { closeDetail() }

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    VStack(spacing: 30) {
                        stampRing(st, big: true)
                            .scaleEffect(stampPop ? 1 : 1.6)
                            .rotationEffect(.degrees(stampPop ? 0 : -14))
                            .opacity(stampPop ? 1 : 0)
                        detailCard(st, ink: ink)
                    }
                    .padding(.top, 64).padding(.horizontal, 28)

                    HStack {
                        Button { closeDetail() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                                .foregroundStyle(theme.ink)
                                .frame(width: 34, height: 34)
                                .background(theme.closeBg, in: Circle())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("入境章").font(Typo.serif(13)).tracking(2).foregroundStyle(theme.soft)
                            Text("入境章详情").font(.system(size: 11)).foregroundStyle(theme.soft)
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.height * 0.82)
            .background {
                ZStack {
                    theme.detailBg
                    motifWatermark(st, ink: ink)   // 逐国暗纹（该国地标意象平铺）
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(theme.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 30, y: -10)
        }
        .transition(.opacity)
    }

    /// 逐国暗纹：按国家码取地标意象（复用地区邮票映射——含 GB/CN/US/SG 手绘地标，
    /// 未覆盖国家用地球兜底），低不透明度斜向平铺——只作纸纹质感，不抢内容。
    private func motifWatermark(_ st: PassportStamp, ink: Color) -> some View {
        let stamp = RegionalStamp.byCode(st.id)
        let cols = 4, rows = 7
        return VStack(spacing: 34) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 44) {
                    ForEach(0..<cols, id: \.self) { c in
                        Group {
                            if let stamp {
                                RegionalMotifView(stamp: stamp, fill: ink, accent: ink)
                                    .frame(width: 30, height: 34)
                            } else {
                                Image(systemName: "globe.asia.australia.fill")
                                    .font(.system(size: 30)).foregroundStyle(ink)
                            }
                        }
                        .rotationEffect(.degrees(-16))
                        .offset(x: r.isMultiple(of: 2) ? 0 : 24)
                        .opacity((r + c).isMultiple(of: 2) ? 1 : 0.6)
                    }
                }
            }
        }
        .opacity(0.05)
        .allowsHitTesting(false)
    }

    private func detailCard(_ st: PassportStamp, ink: Color) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(st.place).font(Typo.serif(20)).fontWeight(.semibold).foregroundStyle(theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Text(st.code3).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.soft)
            }
            Rectangle().fill(theme.line).frame(height: 1).padding(.vertical, 11)
            VStack(spacing: 8) {
                detailRow("入境口岸", st.port)
                detailRow("入境日期", st.date)
                meansEditRow(st, ink: ink)
            }
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .frame(maxWidth: 300)
        .background(theme.detailCardBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
    }

    /// 详情里可调整入境方式：三枚 icon 选项，点选即改并持久化到该国最早一条足迹。
    @ViewBuilder private func meansEditRow(_ st: PassportStamp, ink: Color) -> some View {
        HStack {
            Text("交通方式").font(.system(size: 13)).foregroundStyle(theme.soft)
            Spacer()
            HStack(spacing: 8) {
                ForEach(PostcardStamp.allCases) { m in
                    let active = m == (detail?.means ?? st.means)
                    Button { setMeans(m, for: st) } label: {
                        Image(systemName: m.motif).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(active ? theme.ink : theme.soft.opacity(0.7))
                            .frame(width: 30, height: 26)
                            .background(active ? ink.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7)
                                .stroke(active ? ink.opacity(0.7) : theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 持久化入境方式：写到该国**最早一条**足迹的 `entryMeans`，并即时刷新详情显示。
    private func setMeans(_ means: PostcardStamp, for st: PassportStamp) {
        guard let fp = footprints.first(where: { $0.countryCode == st.id }) else { return }
        fp.entryMeans = means.rawValue
        try? context.save()
        Haptics.selection()
        // 用新方式更新当前详情卡（stamps 会随 @Query 重算，但 detail 是快照，手动同步一份）
        detail = PassportStamp(id: st.id, country: st.country, port: st.port, date: st.date,
                               place: st.place, code3: st.code3, inkHex: st.inkHex,
                               shape: st.shape, means: means)
    }

    private func detailRow(_ label: LocalizedStringKey, _ value: String, icon: String? = nil) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(theme.soft)
            Spacer()
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11)).foregroundStyle(theme.ink) }
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
            }
        }
    }

    private func closeDetail() {
        withAnimation(.easeIn(duration: 0.2)) { stampPop = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { detail = nil }
    }
}

// MARK: - 风格 / 主题 / 数据类型

enum PassportStyle: String, CaseIterable, Identifiable {
    case classic, starlit
    var id: String { rawValue }
    var label: LocalizedStringKey { self == .classic ? "拟真" : "星夜" }
}

enum StampShape {
    case circle, rect, oval
    func size(_ big: Bool) -> CGSize {
        switch self {
        case .circle: return big ? CGSize(width: 150, height: 150) : CGSize(width: 96, height: 96)
        case .rect:   return big ? CGSize(width: 168, height: 104) : CGSize(width: 116, height: 74)
        case .oval:   return big ? CGSize(width: 170, height: 124) : CGSize(width: 116, height: 88)
        }
    }
}

struct PassportStamp: Identifiable {
    let id: String          // countryCode
    let country: String     // 国家本地化名（大写显示）
    let port: String        // 城市口岸（大写）
    let date: String
    let place: String       // 详情标题：城市 · 国家
    let code3: String
    let inkHex: UInt32
    let shape: StampShape
    let means: PostcardStamp    // 入境方式：空运 / 陆运 / 海运（来自足迹的邮票样式）
}

/// 内页主题（拟真米黄 / 星夜深紫）。
struct PageTheme {
    let ink: Color
    let soft: Color
    let line: Color
    let pageBackground: AnyView
    let summaryBg: Color
    let detailBg: Color
    let detailCardBg: Color
    let closeBg: Color

    static func make(_ style: PassportStyle) -> PageTheme {
        switch style {
        case .starlit:
            return PageTheme(
                ink: Color(hex: 0xECE6FF), soft: Color(hex: 0xECE6FF).opacity(0.6),
                line: Color.white.opacity(0.13),
                pageBackground: AnyView(LinearGradient(colors: [Color(hex: 0x191227), Color(hex: 0x110C1B)],
                                                       startPoint: .top, endPoint: .bottom)),
                summaryBg: Color.white.opacity(0.04),
                detailBg: Color(hex: 0x141021),
                detailCardBg: Color.white.opacity(0.05),
                closeBg: Color.white.opacity(0.1))
        case .classic:
            return PageTheme(
                ink: Color(hex: 0x3A2F20), soft: Color(hex: 0x3A2F20).opacity(0.6),
                line: Color(hex: 0x3A2F20).opacity(0.18),
                pageBackground: AnyView(LinearGradient(colors: [Color(hex: 0xF6EEDB), Color(hex: 0xECE0C6)],
                                                       startPoint: .top, endPoint: .bottom)),
                summaryBg: Color(hex: 0x3A2F20).opacity(0.05),
                detailBg: Color(hex: 0xF1E7D1),
                detailCardBg: Color.white.opacity(0.45),
                closeBg: Color.black.opacity(0.06))
        }
    }
}

/// 国籍主题：封面配色 / 国徽 / 名称（CN/US/AE/GB 精绘，其余按 PassportPalette 取色兜底）。
struct NationTheme {
    let primary: String
    let secondary: String
    let native: String
    let code3: String
    let nameSize: CGFloat
    let emblem: String       // SF Symbol
    private let cover: UInt32
    private let cover2: UInt32
    private let foil: UInt32

    func coverInk(_ s: PassportStyle) -> Color { s == .starlit ? .white : Color(hex: foil) }
    func emblemStroke(_ s: PassportStyle) -> Color {
        s == .starlit ? Color(hex: 0xFFC9E0).opacity(0.8) : Color(hex: foil)
    }
    func accent(_ s: PassportStyle) -> Color { s == .starlit ? Color(hex: 0xFF8AB8) : Color(hex: foil) }

    @ViewBuilder func coverBackground(_ s: PassportStyle) -> some View {
        switch s {
        case .starlit:
            LinearGradient(colors: [Color(hex: 0x221636), Color(hex: cover2).darkened(0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .classic:
            LinearGradient(colors: [Color(hex: cover).lightened(0.07), Color(hex: cover), Color(hex: cover2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func resolve(_ code: String) -> NationTheme {
        let cc = code.uppercased()
        if let s = specific[cc] { return s }
        let pal = PassportPalette.coverHex(for: cc)
        let name = (CountryInfo.localizedName(for: cc) ?? cc).uppercased()
        return NationTheme(primary: name, secondary: "", native: "", code3: iso3(cc),
                           nameSize: name.count > 18 ? 13 : 17, emblem: "star.fill",
                           cover: pal.0, cover2: pal.1, foil: 0xC9A24B)
    }

    private static let specific: [String: NationTheme] = [
        "CN": NationTheme(primary: "中华人民共和国", secondary: "THE PEOPLE'S REPUBLIC OF CHINA",
                          native: "护照", code3: "CHN", nameSize: 19, emblem: "star.fill",
                          cover: 0x6D1322, cover2: 0x430A13, foil: 0xCDA349),
        "US": NationTheme(primary: "UNITED STATES OF AMERICA", secondary: "",
                          native: "", code3: "USA", nameSize: 14, emblem: "shield.fill",
                          cover: 0x16294D, cover2: 0x0B1830, foil: 0xC7A64A),
        "AE": NationTheme(primary: "الإمارات العربية المتحدة", secondary: "UNITED ARAB EMIRATES",
                          native: "جواز سفر", code3: "ARE", nameSize: 17, emblem: "bird.fill",
                          cover: 0x0F1F3A, cover2: 0x081123, foil: 0xC8A24C),
        "GB": NationTheme(primary: "UNITED KINGDOM", secondary: "OF GREAT BRITAIN AND NORTHERN IRELAND",
                          native: "", code3: "GBR", nameSize: 18, emblem: "crown.fill",
                          cover: 0x3C1420, cover2: 0x240A12, foil: 0xC9A44D),
    ]

    static func iso3(_ code: String) -> String { iso3map[code.uppercased()] ?? code.uppercased() }

    private static let iso3map: [String: String] = [
        "CN": "CHN", "US": "USA", "AE": "ARE", "GB": "GBR", "JP": "JPN", "FR": "FRA",
        "ES": "ESP", "IT": "ITA", "DE": "DEU", "NL": "NLD", "PT": "PRT", "GR": "GRC",
        "CH": "CHE", "TR": "TUR", "TH": "THA", "SG": "SGP", "VN": "VNM", "KR": "KOR",
        "IN": "IND", "ID": "IDN", "MY": "MYS", "PH": "PHL", "AU": "AUS", "NZ": "NZL",
        "CA": "CAN", "MX": "MEX", "BR": "BRA", "AR": "ARG", "PE": "PER", "EG": "EGY",
        "MA": "MAR", "ZA": "ZAF", "SA": "SAU", "QA": "QAT", "DK": "DNK", "SE": "SWE",
        "NO": "NOR", "FI": "FIN", "IS": "ISL", "IE": "IRL", "BE": "BEL", "AT": "AUT",
        "RU": "RUS", "MV": "MDV", "HK": "HKG", "TW": "TWN", "MO": "MAC",
    ]
}

extension PassportPalette {
    /// 封面取色（hex），供新护照封面用；与 cover(for:) 同口径。
    static func coverHex(for code: String) -> (UInt32, UInt32) {
        let red: (UInt32, UInt32) = (0x6E1420, 0x44101A)
        let navy: (UInt32, UInt32) = (0x16284A, 0x0E1B36)
        let green: (UInt32, UInt32) = (0x1E4D34, 0x113021)
        let bordeaux: (UInt32, UInt32) = (0x5A1A2A, 0x3A1019)
        let black: (UInt32, UInt32) = (0x1A1A1E, 0x0C0C10)
        let redSet: Set<String> = ["CN","JP","SG","CH","TR","VN","RU","PL","HK","TW","RS","MO"]
        let greenSet: Set<String> = ["SA","PK","NG","BD","MA","DZ"]
        let bordeauxSet: Set<String> = ["GB","FR","DE","IT","ES","NL","PT","GR","IE"]
        let blackSet: Set<String> = ["NZ"]
        let cc = code.uppercased()
        if redSet.contains(cc) { return red }
        if greenSet.contains(cc) { return green }
        if bordeauxSet.contains(cc) { return bordeaux }
        if blackSet.contains(cc) { return black }
        return navy
    }
}

/// 简单的流式换行容器（资料页国家码 chips 用）。
private struct FlowRow<Content: View>: View {
    var spacing: CGFloat = 5
    @ViewBuilder var content: Content
    var body: some View { _Flow(spacing: spacing) { content } }
}

private struct _Flow: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

/// 资料页斜纹底纹路径。
private struct StripePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.height))
            p.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += 9
        }
        return p
    }
}

// MARK: - 颜色明暗工具

extension Color {
    func lightened(_ amount: Double) -> Color { blended(with: .white, amount: amount) }
    func darkened(_ amount: Double) -> Color { blended(with: .black, amount: amount) }
    private func blended(with other: Color, amount: Double) -> Color {
        let a = min(max(amount, 0), 1)
        let c1 = UIColor(self), c2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, o1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, o2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &o1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &o2)
        return Color(red: r1 + (r2 - r1) * a, green: g1 + (g2 - g1) * a, blue: b1 + (b2 - b1) * a)
    }
}

/// 护照封面按国籍取色（红 / 蓝 / 墨绿 / 酒红 / 黑），保留旧 API 供他处引用。
enum PassportPalette {
    private static let red = (Color(hex: 0x6E1420), Color(hex: 0x44101A))
    private static let navy = (Color(hex: 0x16284A), Color(hex: 0x0E1B36))
    private static let green = (Color(hex: 0x1E4D34), Color(hex: 0x113021))
    private static let bordeaux = (Color(hex: 0x5A1A2A), Color(hex: 0x3A1019))
    private static let black = (Color(hex: 0x1A1A1E), Color(hex: 0x0C0C10))

    private static let map: [String: (Color, Color)] = [
        "CN": red, "JP": red, "SG": red, "CH": red, "TR": red, "VN": red, "RU": red,
        "PL": red, "HK": red, "TW": red, "RS": red, "MO": red,
        "SA": green, "PK": green, "NG": green, "BD": green, "MA": green, "DZ": green,
        "GB": bordeaux, "FR": bordeaux, "DE": bordeaux, "IT": bordeaux, "ES": bordeaux,
        "NL": bordeaux, "PT": bordeaux, "GR": bordeaux, "IE": bordeaux,
        "NZ": black,
        "US": navy, "AU": navy, "BR": navy, "IN": navy, "KR": navy, "TH": navy,
        "AE": navy, "QA": navy, "EG": navy, "ZA": navy, "CA": navy, "MX": navy, "ID": navy,
    ]
    static func cover(for code: String) -> (Color, Color) { map[code.uppercased()] ?? navy }
}
