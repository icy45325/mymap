import SwiftUI
import SwiftData
import MapKit

/// 心愿单：想去但还没去的地方。可在此搜索添加，或在真实地图上点选标记。
struct WishlistView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Wish.createdAt, order: .reverse) private var wishes: [Wish]

    @State private var showAdd = false

    var body: some View {
        Group {
            if wishes.isEmpty { emptyState }
            else { list }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("心愿单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .tint(Color.nPink)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAdd) { AddWishView() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square").font(.system(size: 44)).foregroundStyle(Color.nPink)
            Text("还没有心愿").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
            Text("搜索添加想去的地方，或在地图上点选标记")
                .font(.system(size: 12.5)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { showAdd = true } label: {
                Label("添加心愿", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold)).padding(.vertical, 13).padding(.horizontal, 22)
                    .background(LinearGradient.neonH, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(wishes) { wish in wishCard(wish) }
            }
            .padding(16)
        }
    }

    /// 大卡片：放大国旗 + 国家/城市 + 推荐地点 / 最佳季节 / 游玩简述。
    private func wishCard(_ wish: Wish) -> some View {
        let guide = DestinationGuide.of(wish.countryCode)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text(wish.flag).font(.system(size: 44))
                VStack(alignment: .leading, spacing: 3) {
                    Text(wish.title).font(Typo.serif(20)).foregroundStyle(Color.text).lineLimit(1)
                    if let country = wish.countryName, country != wish.title {
                        Text(country).font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                }
                Spacer()
                Button {
                    context.delete(wish)
                    try? context.save()
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(Color.textMuted)
                }
            }
            if let g = guide {
                Divider().overlay(Color.line)
                guideRow("mappin.and.ellipse", "推荐", g.spots, Color.nPink)
                guideRow("sun.max.fill", "最佳季节", g.season, Color.nOrange)
                Text(g.blurb).font(.system(size: 12.5)).lineSpacing(3)
                    .foregroundStyle(Color(hex: 0xC8C8DC))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.line, lineWidth: 1))
    }

    private func guideRow(_ icon: String, _ label: LocalizedStringKey, _ value: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint).frame(width: 16)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
                .frame(width: 56, alignment: .leading)
            Text(value).font(.system(size: 12.5)).foregroundStyle(Color.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// 添加心愿：搜索地点（复用 PlaceSearchService），或从未去过的热门目的地预设里一键添加。
private struct AddWishView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = PlaceSearchService()
    @State private var query = ""

    @Query private var footprints: [Footprint]
    @Query private var wishes: [Wish]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.textMuted)
                    TextField("搜索想去的城市 / 国家", text: $query)
                        .foregroundStyle(Color.textPrimary)
                        .onChange(of: query) { _, q in search.search(q, near: nil) }
                }
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
                .padding(16)

                if search.isSearching { ProgressView().tint(Color.nPink).padding(.top, 8) }

                if query.isEmpty && search.results.isEmpty {
                    presetSuggestions
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(search.results) { result in
                                Button { add(result) } label: {
                                    HStack {
                                        Image(systemName: "mappin.circle").foregroundStyle(Color.textMuted)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.name).foregroundStyle(Color.textPrimary)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle).font(.caption).foregroundStyle(Color.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "heart").foregroundStyle(Color.nPink)
                                    }
                                    .padding(.vertical, 10).padding(.horizontal, 16)
                                }
                                Divider().overlay(Color.lineSoft)
                            }
                        }
                    }
                }
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("添加心愿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    // MARK: - 未去过的热门目的地预设

    /// 已去过 / 已心愿的国家码，预设里要排除。
    private var takenCountryCodes: Set<String> {
        var set = Set(footprints.compactMap { $0.countryCode })
        set.formUnion(wishes.compactMap { $0.countryCode })
        return set
    }

    private var suggestions: [PresetDestination] {
        PresetDestination.popular.filter { !takenCountryCodes.contains($0.code) }
    }

    @ViewBuilder private var presetSuggestions: some View {
        if suggestions.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "globe.asia.australia.fill").font(.system(size: 38)).foregroundStyle(Color.nPurple)
                Text("热门目的地都在你的清单里了 ✦").font(.system(size: 12.5)).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("还没去过的热门目的地").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.muted)
                        .padding(.horizontal, 16)
                    FlowChips(items: suggestions) { dest in
                        Button { addPreset(dest) } label: {
                            HStack(spacing: 6) {
                                Text(flagEmoji(dest.code)).font(.system(size: 16))
                                Text(dest.displayName).font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.text)
                                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.nPink)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .background(Color.panel, in: Capsule())
                            .overlay(Capsule().stroke(Color.nPink.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
            }
        }
    }

    private func addPreset(_ dest: PresetDestination) {
        guard !takenCountryCodes.contains(dest.code) else { return }
        let wish = Wish(placeName: dest.displayName,
                        coordinate: dest.coordinate,
                        cityName: nil,
                        countryCode: dest.code)
        context.insert(wish)
        do { try context.save() } catch { assertionFailure("保存心愿失败: \(error)") }
        Haptics.light()
    }

    private func add(_ result: PlaceResult) {
        let code = Boundaries.shared.countryCode(at: result.coordinate) ?? result.countryCode
        // 同地点（国家 + 城市）已在心愿单则不重复
        let existing = (try? context.fetch(FetchDescriptor<Wish>())) ?? []
        if existing.contains(where: { $0.countryCode == code && $0.cityName == result.cityName }) {
            dismiss(); return
        }
        let wish = Wish(placeName: result.name,
                        coordinate: result.coordinate,
                        cityName: result.cityName,
                        countryCode: code)
        context.insert(wish)
        do { try context.save() } catch { assertionFailure("保存心愿失败: \(error)") }
        Haptics.light()
        dismiss()
    }
}

// MARK: - 热门目的地预设

/// 未去过的热门目的地（国家级）。名字随系统语言由国家码派生；坐标取代表性城市。
struct PresetDestination: Identifiable {
    let code: String      // ISO_A2
    let lat: Double
    let lon: Double

    var id: String { code }
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    var displayName: String { CountryInfo.localizedName(for: code) ?? code }

    /// 精选热门目的地（覆盖各大洲），按常见向往度大致排序。
    static let popular: [PresetDestination] = [
        .init(code: "JP", lat: 35.68, lon: 139.69),   // 东京
        .init(code: "FR", lat: 48.85, lon: 2.35),     // 巴黎
        .init(code: "IT", lat: 41.90, lon: 12.50),    // 罗马
        .init(code: "CH", lat: 46.95, lon: 7.45),     // 伯尔尼
        .init(code: "GR", lat: 37.98, lon: 23.73),    // 雅典
        .init(code: "ES", lat: 40.42, lon: -3.70),    // 马德里
        .init(code: "GB", lat: 51.51, lon: -0.13),    // 伦敦
        .init(code: "IS", lat: 64.15, lon: -21.94),   // 雷克雅未克
        .init(code: "NO", lat: 59.91, lon: 10.75),    // 奥斯陆
        .init(code: "NL", lat: 52.37, lon: 4.90),     // 阿姆斯特丹
        .init(code: "PT", lat: 38.72, lon: -9.14),    // 里斯本
        .init(code: "TR", lat: 41.01, lon: 28.98),    // 伊斯坦布尔
        .init(code: "EG", lat: 30.04, lon: 31.24),    // 开罗
        .init(code: "MA", lat: 31.63, lon: -7.99),    // 马拉喀什
        .init(code: "ZA", lat: -33.92, lon: 18.42),   // 开普敦
        .init(code: "US", lat: 40.71, lon: -74.01),   // 纽约
        .init(code: "CA", lat: 43.65, lon: -79.38),   // 多伦多
        .init(code: "MX", lat: 19.43, lon: -99.13),   // 墨西哥城
        .init(code: "BR", lat: -22.91, lon: -43.17),  // 里约
        .init(code: "PE", lat: -13.16, lon: -72.54),  // 库斯科
        .init(code: "AR", lat: -34.60, lon: -58.38),  // 布宜诺斯艾利斯
        .init(code: "TH", lat: 13.76, lon: 100.50),   // 曼谷
        .init(code: "SG", lat: 1.35, lon: 103.82),    // 新加坡
        .init(code: "VN", lat: 21.03, lon: 105.85),   // 河内
        .init(code: "ID", lat: -8.65, lon: 115.22),   // 巴厘岛
        .init(code: "KR", lat: 37.57, lon: 126.98),   // 首尔
        .init(code: "IN", lat: 28.61, lon: 77.21),    // 德里
        .init(code: "MV", lat: 3.20, lon: 73.22),     // 马尔代夫
        .init(code: "AU", lat: -33.87, lon: 151.21),  // 悉尼
        .init(code: "NZ", lat: -36.85, lon: 174.76),  // 奥克兰
    ]
}

/// 自动换行的 chip 容器（iOS 16+ Layout）。
private struct FlowChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { content($0) }
        }
    }
}

/// 简单流式布局：从左到右排列，超宽自动换行。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
