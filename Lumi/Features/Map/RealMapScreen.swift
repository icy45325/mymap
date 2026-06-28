import SwiftUI
import SwiftData
import CoreLocation

/// 放大后的真实 MapKit 地图全屏页。
///
/// 点一个国家 →「我去过这里（选年份点亮）」或「加入心愿单」。
/// 国家判定走离线 point-in-polygon（§5.1）；只到国家级——城市可略过（按需求）。
struct RealMapScreen: View {

    let provider: MapProvider
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Footprint.visitedAt, order: .reverse) private var footprints: [Footprint]
    @Query private var wishes: [Wish]

    @State private var tapped: TappedPlace?
    @State private var yearPickFor: TappedPlace?
    @State private var cityRecordFor: TappedPlace?

    fileprivate struct TappedPlace: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let countryCode: String
        var countryName: String { CountryInfo.localizedName(for: countryCode) ?? String(localized: "这个国家") }
    }

    private var litCountryCodes: Set<String> { Set(footprints.compactMap { $0.countryCode }) }
    private var litEmirateCodes: Set<String> { Set(footprints.compactMap { $0.subRegionCode }) }
    /// 心愿国家（已点亮的不再算心愿，避免与点亮区重叠抢色）。
    private var wishCountryCodes: Set<String> {
        Set(wishes.compactMap { $0.countryCode }).subtracting(litCountryCodes)
    }

    private var renderState: MapRenderState {
        MapRenderState(
            litRegions: Boundaries.shared.regions(forCountryCodes: litCountryCodes,
                                                  emirateCodes: litEmirateCodes),
            wishRegions: Boundaries.shared.regions(forCountryCodes: wishCountryCodes,
                                                   emirateCodes: []),
            pins: footprints.map { MapPin(id: $0.id, coordinate: $0.coordinate) },
            onTapCoordinate: handleTap)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.bg.ignoresSafeArea()
            provider.makeMapView(renderState).ignoresSafeArea()
            hint
            closeButton.frame(maxWidth: .infinity, alignment: .trailing)
            legend.frame(maxHeight: .infinity, alignment: .bottom)
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(tapped?.countryName ?? "", isPresented: tappedDialog,
                            titleVisibility: .visible, presenting: tapped) { place in
            Button(litCountryCodes.contains(place.countryCode) ? "已点亮 · 再记一次" : "我去过这里 ✦") {
                tapped = nil
                yearPickFor = place
            }
            if litCountryCodes.contains(place.countryCode) {
                Button("看看在这里去过的城市") { let p = place; tapped = nil; cityRecordFor = p }
            }
            Button("加入心愿单") { addWish(place); tapped = nil }
            Button("取消", role: .cancel) { tapped = nil }
        }
        .sheet(item: $yearPickFor) { place in
            VisitDetailsSheet(place: place) { year, month, cities in
                lightCountry(place, year: year, month: month, cities: cities)
            }
        }
        .sheet(item: $cityRecordFor) { place in
            CountryCitiesSheet(countryCode: place.countryCode, countryName: place.countryName,
                               footprints: footprints.filter { $0.countryCode == place.countryCode })
        }
    }

    // MARK: - 顶部提示 / 关闭

    private var hint: some View {
        Text("点一个国家：标记去过或加入心愿")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.text)
            .padding(.vertical, 8).padding(.horizontal, 14)
            .background(Color.panel.opacity(0.85), in: Capsule())
            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
            .padding(.top, 54)
            .frame(maxWidth: .infinity, alignment: .center)
            .allowsHitTesting(false)
    }

    /// 颜色图例：点亮（粉）/ 心愿（青）。心愿为空时不显示心愿项。
    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: .nPink, label: "去过")
            if !wishCountryCodes.isEmpty {
                legendItem(color: .nCyan, label: "心愿")
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 16)
        .background(Color.panel.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(Color.line, lineWidth: 1))
        .padding(.bottom, 32)
        .allowsHitTesting(false)
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.85)).frame(width: 9, height: 9)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.text)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.42), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .padding(.trailing, 22).padding(.top, 54)
    }

    // MARK: - 动作

    private func handleTap(_ coordinate: CLLocationCoordinate2D) {
        // 落在某个国家才弹选择；落公海忽略
        guard let code = Boundaries.shared.countryCode(at: coordinate) else { return }
        tapped = TappedPlace(coordinate: coordinate, countryCode: code)
    }

    private func lightCountry(_ place: TappedPlace, year: Int, month: Int, cities: [PresetCity]) {
        let prior = Set(footprints.compactMap { $0.countryCode })
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()

        // 勾选了城市 → 每个城市各点亮一条；未选 → 以国家落点一条
        let targets: [(name: String, coord: CLLocationCoordinate2D, city: String?)] = cities.isEmpty
            ? [(place.countryName, place.coordinate, nil)]
            : cities.map { ($0.name, $0.coordinate, $0.name) }

        for t in targets {
            let footprint = Footprint(placeName: t.name, coordinate: t.coord, cityName: t.city, visitedAt: date)
            footprint.countryCode = place.countryCode
            if place.countryCode == "AE" {
                footprint.subRegionCode = Boundaries.shared.emirateCode(at: t.coord)
            }
            context.insert(footprint)
            context.insert(Card(footprint: footprint))
            Analytics.log(.footprintCreated(countryCode: place.countryCode, hasPhoto: false, companionsCount: 0))
        }
        try? context.save()

        if !prior.contains(place.countryCode) {
            Analytics.log(.countryLit(countryCode: place.countryCode, totalLit: prior.count + 1))
        }
        WidgetSync.refresh(context)
    }

    private func addWish(_ place: TappedPlace) {
        // 已在心愿单（同国家、未指定城市）则不重复添加
        let existing = (try? context.fetch(FetchDescriptor<Wish>())) ?? []
        guard !existing.contains(where: { $0.countryCode == place.countryCode && $0.cityName == nil }) else { return }

        let wish = Wish(placeName: place.countryName,
                        coordinate: place.coordinate,
                        countryCode: place.countryCode)
        context.insert(wish)
        do { try context.save() } catch { assertionFailure("保存心愿失败: \(error)") }
    }

    private var tappedDialog: Binding<Bool> {
        Binding(get: { tapped != nil }, set: { if !$0 { tapped = nil } })
    }
}

/// 选择「哪年/哪月去的」+ 打卡城市（默认展开、开关多选）——快速点亮用。
private struct VisitDetailsSheet: View {
    let place: RealMapScreen.TappedPlace
    let onPick: (_ year: Int, _ month: Int, _ cities: [PresetCity]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var month: Int
    @State private var selectedCities: Set<PresetCity> = []
    private let years: [Int]
    private let cities: [PresetCity]

    init(place: RealMapScreen.TappedPlace,
         onPick: @escaping (Int, Int, [PresetCity]) -> Void) {
        self.place = place
        self.onPick = onPick
        let cal = Calendar.current
        let current = cal.component(.year, from: Date())
        self.years = Array(stride(from: current, through: current - 60, by: -1))
        _year = State(initialValue: current)
        _month = State(initialValue: cal.component(.month, from: Date()))
        self.cities = CityCatalog.cities(for: place.countryCode)
    }

    private var monthSymbols: [String] { Calendar.current.shortMonthSymbols }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("你哪一年去的 \(place.countryName)？")
                    .font(Typo.serif(20)).foregroundStyle(Color.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    Picker("", selection: $year) {
                        ForEach(years, id: \.self) { Text("\($0) 年").tag($0) }
                    }
                    .pickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                    Picker("", selection: $month) {
                        ForEach(1...12, id: \.self) { m in Text(monthSymbols[m - 1]).tag(m) }
                    }
                    .pickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                }
                .frame(height: 130)

                if !cities.isEmpty { citySection }

                Button { onPick(year, month, Array(selectedCities)); dismiss() } label: {
                    Text(buttonTitle).font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(LinearGradient.neonH, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24).padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .background(Color.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private var buttonTitle: LocalizedStringKey {
        selectedCities.isEmpty ? "点亮 ✦" : "点亮 \(selectedCities.count) 城 ✦"
    }

    /// 打卡城市：默认展开、开关多选；不选则以国家落点。
    private var citySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("打卡城市（可选 · 可多选）").font(.subheadline).foregroundStyle(Color.muted)
                .padding(.horizontal, 8)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(cities) { city in
                        Toggle(isOn: Binding(
                            get: { selectedCities.contains(city) },
                            set: { on in if on { selectedCities.insert(city) } else { selectedCities.remove(city) } }
                        )) {
                            Text(city.name).foregroundStyle(Color.text)
                        }
                        .tint(Color.nPink)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }
}

/// 看看在某个国家实际去过哪些城市的记录（来自已点亮足迹）。
private struct CountryCitiesSheet: View {
    let countryCode: String
    let countryName: String
    let footprints: [Footprint]     // 已过滤到该国

    @Environment(\.dismiss) private var dismiss
    private static let df: Date.FormatStyle = .dateTime.year().month(.abbreviated)

    /// 去过的城市：按城市名去重，取最近一次日期 + 次数；无城市名归「未指定城市」。
    private var visited: [(name: String, date: Date, count: Int)] {
        var byCity: [String: (date: Date, count: Int)] = [:]
        for fp in footprints {
            let name = fp.cityName ?? String(localized: "未指定城市")
            if let e = byCity[name] {
                byCity[name] = (max(e.date, fp.visitedAt), e.count + 1)
            } else {
                byCity[name] = (fp.visitedAt, 1)
            }
        }
        return byCity.map { ($0.key, $0.value.date, $0.value.count) }.sorted { $0.date > $1.date }
    }

    /// 预设里还没点亮的城市（轻提示）。
    private var notVisited: [PresetCity] {
        let v = Set(footprints.compactMap { $0.cityName })
        return CityCatalog.cities(for: countryCode).filter { !v.contains($0.name) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(visited, id: \.name) { c in
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 20))
                                .foregroundStyle(Color.nPink)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.text)
                                Text(c.date.formatted(Self.df)).font(.system(size: 11)).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            if c.count > 1 {
                                Text("×\(c.count)").font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.nCyan)
                                    .padding(.vertical, 3).padding(.horizontal, 8)
                                    .background(Color.panel, in: Capsule())
                            }
                        }
                        .padding(12).panelCard(14)
                    }

                    if !notVisited.isEmpty {
                        Text("还没去过").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.muted).padding(.top, 12).padding(.horizontal, 4)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(notVisited) { city in
                                    Text(city.name).font(.system(size: 12)).foregroundStyle(Color.faint)
                                        .padding(.vertical, 6).padding(.horizontal, 12)
                                        .background(Color.panel.opacity(0.6), in: Capsule())
                                        .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 20).padding(.top, 10)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("\(CountryInfo.flag(for: countryCode)) \(countryName)")
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
