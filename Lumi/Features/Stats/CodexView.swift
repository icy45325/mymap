import SwiftUI
import SwiftData

/// 收集图鉴：地区邮票 / 节日限定章 / 基础邮票·邮戳 成册展示。
/// 解锁态**全派生、零新增存储**：
/// - 地区邮票 = 点亮过该国（litCountryCodes）
/// - 节日章 = 收到过命中该节日窗口的明信片（isReceived 足迹 × Festival.match）
/// - 基础邮票 & 通用邮戳 = 默认解锁（陈列）
struct CodexView: View {

    @Query private var footprints: [Footprint]

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
    private var collectedTotal: Int {
        unlockedRegionalCount + collectedFestivals.count + PostcardStamp.allCases.count + 1  // +1 通用邮戳
    }
    private var codexTotal: Int {
        RegionalStamp.all.count + Festival.allCases.count + PostcardStamp.allCases.count + 1
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                section("地区邮票", subtitle: "点亮该国家即解锁 · 仅限该国足迹的明信片") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(RegionalStamp.all) { r in regionalCell(r) }
                    }
                }
                section("节日限定章", subtitle: "节日前后 5 天限时可用（地区性节日仅限该地区足迹）· 收到贴此章的明信片即收集") {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(Festival.allCases) { f in festivalCell(f) }
                    }
                }
                section("基础邮票 · 邮戳", subtitle: "默认解锁") {
                    HStack(spacing: 14) {
                        ForEach(PostcardStamp.allCases) { s in
                            cellFrame(unlocked: true) {
                                PostcardStampView(stamp: s).frame(width: 44, height: 53)
                            } title: { Text(s.label) }
                        }
                        cellFrame(unlocked: true) {
                            genericPostmark
                        } title: { Text("通用邮戳") }
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

    private func regionalCell(_ r: RegionalStamp) -> some View {
        let unlocked = litCodes.contains(r.code)
        return cellFrame(unlocked: unlocked) {
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

    private func festivalCell(_ f: Festival) -> some View {
        let collected = collectedFestivals.contains(f)
        return cellFrame(unlocked: collected) {
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

#Preview {
    NavigationStack { CodexView() }
        .modelContainer(for: [Footprint.self, Trip.self, Card.self], inMemory: true)
}
