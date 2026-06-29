import SwiftUI
import SwiftData
import CoreLocation

/// 放大后的真实 MapKit 地图全屏页。
///
/// 点一个国家 → 弹出**国家操作半浮窗**（`CountryActionSheet`）：
/// 点亮国家 / 加入心愿 / 看去过的城市 / 推荐城市一键心愿·点亮，集中在一处。
/// 国家判定走离线 point-in-polygon（§5.1）；只到国家级。
struct RealMapScreen: View {

    let provider: MapProvider
    let onClose: () -> Void

    @Query(sort: \Footprint.visitedAt, order: .reverse) private var footprints: [Footprint]
    @Query private var wishes: [Wish]

    @State private var tapped: TappedPlace?

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
        .sheet(item: $tapped) { place in
            CountryActionSheet(countryCode: place.countryCode,
                               countryName: place.countryName,
                               tapCoordinate: place.coordinate)
        }
    }

    // MARK: - 顶部提示 / 关闭 / 图例

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
        // 落在某个国家才弹；落公海忽略
        guard let code = Boundaries.shared.countryCode(at: coordinate) else { return }
        tapped = TappedPlace(coordinate: coordinate, countryCode: code)
    }
}

// MARK: - 国家操作半浮窗（hub）

/// 点一个国家后弹出的整合面板：点亮 / 心愿 / 去过城市入口 / 推荐城市一键操作。
/// 自带 `@Query`，所有改动即时反映（点亮一城后列表立刻更新）。
private struct CountryActionSheet: View {
    let countryCode: String
    let countryName: String
    let tapCoordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Footprint.visitedAt, order: .reverse) private var allFootprints: [Footprint]
    @Query private var allWishes: [Wish]

    // 派生
    private var footprints: [Footprint] { allFootprints.filter { $0.countryCode == countryCode } }
    private var isLit: Bool { !footprints.isEmpty }
    private var presetCities: [PresetCity] { CityCatalog.cities(for: countryCode) }
    private var visitedCityNames: Set<String> { Set(footprints.compactMap { $0.cityName }) }
    private var countryWished: Bool {
        allWishes.contains { $0.countryCode == countryCode && $0.cityName == nil }
    }
    private func cityWished(_ c: PresetCity) -> Bool {
        allWishes.contains { $0.countryCode == countryCode && $0.cityName == c.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    actionButtons
                    if isLit { visitedEntry }
                    if !presetCities.isEmpty { recommendedSection }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 20).padding(.top, 12)
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
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 12) {
            Text(CountryInfo.flag(for: countryCode)).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 3) {
                Text(countryName).font(Typo.serif(24)).foregroundStyle(Color.text)
                Text(isLit ? "已点亮 · \(visitedCityNames.count) 城" : "还没点亮")
                    .font(.system(size: 12))
                    .foregroundStyle(isLit ? Color.nPink : Color.muted)
            }
            Spacer()
        }
    }

    // MARK: 主操作（点亮 + 心愿）

    private var actionButtons: some View {
        HStack(spacing: 10) {
            NavigationLink {
                VisitPickerScreen(countryCode: countryCode, countryName: countryName) { year, month, cities in
                    lightCountry(year: year, month: month, cities: cities)
                    dismiss()
                }
            } label: {
                actionLabel(icon: "sparkles",
                            title: isLit ? "再记一次" : "我去过这里",
                            fill: true)
            }

            Button {
                toggleCountryWish()
            } label: {
                actionLabel(icon: countryWished ? "heart.fill" : "heart",
                            title: countryWished ? "已在心愿" : "加入心愿",
                            fill: false, active: countryWished)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(icon: String, title: LocalizedStringKey, fill: Bool, active: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(title).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(fill ? .white : (active ? Color.nCyan : Color.text))
        .frame(maxWidth: .infinity).padding(.vertical, 13)
        .background {
            if fill {
                Capsule().fill(LinearGradient.neonH)
            } else {
                Capsule().fill(Color.panel)
                    .overlay(Capsule().stroke(active ? Color.nCyan.opacity(0.6) : Color.line, lineWidth: 1))
            }
        }
    }

    // MARK: 去过的城市入口

    private var visitedEntry: some View {
        NavigationLink {
            CountryCitiesList(countryCode: countryCode, countryName: countryName, footprints: footprints)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 17)).foregroundStyle(Color.nPink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("看看在这里去过的城市").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
                    Text("\(visitedCityNames.count) 城 · 共 \(footprints.count) 次记录")
                        .font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
            }
            .padding(14).panelCard(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: 推荐城市（一键心愿 / 点亮）

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("推荐城市").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
                .padding(.horizontal, 4)
            VStack(spacing: 8) {
                ForEach(presetCities) { city in
                    cityRow(city)
                }
            }
        }
    }

    private func cityRow(_ city: PresetCity) -> some View {
        let visited = visitedCityNames.contains(city.name)
        let wished = cityWished(city)
        return HStack(spacing: 10) {
            Image(systemName: visited ? "checkmark.circle.fill" : "mappin.circle")
                .font(.system(size: 18)).foregroundStyle(visited ? Color.nPink : Color.muted)
            Text(city.name).font(.system(size: 14, weight: .medium))
                .foregroundStyle(visited ? Color.text : Color(hex: 0xC8C8DC))
            Spacer()
            if visited {
                Text("已点亮").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.nPink)
            } else {
                // 一键心愿
                Button { toggleCityWish(city) } label: {
                    Image(systemName: wished ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(wished ? Color.nCyan : Color.muted)
                        .frame(width: 34, height: 30)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                // 一键点亮（当月当年快速记录）
                Button { quickLightCity(city) } label: {
                    Text("点亮").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .padding(.vertical, 7).padding(.horizontal, 12)
                        .background(LinearGradient.neonH, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(Color.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 数据动作

    /// 点亮国家（年/月 + 可选多城）；无城以国家落点一条。
    private func lightCountry(year: Int, month: Int, cities: [PresetCity]) {
        let prior = isLit
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let targets: [(name: String, coord: CLLocationCoordinate2D, city: String?)] = cities.isEmpty
            ? [(countryName, tapCoordinate, nil)]
            : cities.map { ($0.name, $0.coordinate, $0.name) }
        for t in targets { insertFootprint(name: t.name, coord: t.coord, city: t.city, date: date) }
        try? context.save()
        if !prior { Analytics.log(.countryLit(countryCode: countryCode, totalLit: distinctLitCount())) }
        Haptics.success()
        WidgetSync.refresh(context)
    }

    /// 推荐城市一键点亮：以当前年月快速记录一条。
    private func quickLightCity(_ city: PresetCity) {
        let prior = isLit
        insertFootprint(name: city.name, coord: city.coordinate, city: city.name, date: Date())
        // 点亮后若该城在心愿里，移除对应心愿
        removeCityWish(city)
        try? context.save()
        if !prior { Analytics.log(.countryLit(countryCode: countryCode, totalLit: distinctLitCount())) }
        Haptics.success()
        WidgetSync.refresh(context)
    }

    private func distinctLitCount() -> Int {
        Set(allFootprints.compactMap { $0.countryCode }).union([countryCode]).count
    }

    private func insertFootprint(name: String, coord: CLLocationCoordinate2D, city: String?, date: Date) {
        let fp = Footprint(placeName: name, coordinate: coord, cityName: city, visitedAt: date)
        fp.countryCode = countryCode
        if countryCode == "AE" { fp.subRegionCode = Boundaries.shared.emirateCode(at: coord) }
        context.insert(fp)
        context.insert(Card(footprint: fp))
        Analytics.log(.footprintCreated(countryCode: countryCode, hasPhoto: false, companionsCount: 0))
    }

    // MARK: 心愿

    private func toggleCountryWish() {
        if let existing = allWishes.first(where: { $0.countryCode == countryCode && $0.cityName == nil }) {
            context.delete(existing)
        } else {
            context.insert(Wish(placeName: countryName, coordinate: tapCoordinate, countryCode: countryCode))
        }
        try? context.save()
        Haptics.selection()
    }

    private func toggleCityWish(_ city: PresetCity) {
        if allWishes.contains(where: { $0.countryCode == countryCode && $0.cityName == city.name }) {
            removeCityWish(city)
        } else {
            context.insert(Wish(placeName: city.name, coordinate: city.coordinate,
                                cityName: city.name, countryCode: countryCode))
        }
        try? context.save()
        Haptics.selection()
    }

    private func removeCityWish(_ city: PresetCity) {
        for w in allWishes where w.countryCode == countryCode && w.cityName == city.name {
            context.delete(w)
        }
    }
}

// MARK: - 年份/城市选择（hub 内 push）

/// 选择「哪年/哪月去的」+ 打卡城市（默认展开、开关多选）——快速点亮用。
/// 作为 `CountryActionSheet` 的下钻页（无独立 NavigationStack）。
private struct VisitPickerScreen: View {
    let countryCode: String
    let countryName: String
    let onConfirm: (_ year: Int, _ month: Int, _ cities: [PresetCity]) -> Void

    @State private var year: Int
    @State private var month: Int
    @State private var selectedCities: Set<PresetCity> = []
    private let years: [Int]
    private let cities: [PresetCity]

    init(countryCode: String, countryName: String,
         onConfirm: @escaping (Int, Int, [PresetCity]) -> Void) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.onConfirm = onConfirm
        let cal = Calendar.current
        let current = cal.component(.year, from: Date())
        self.years = Array(stride(from: current, through: current - 60, by: -1))
        _year = State(initialValue: current)
        _month = State(initialValue: cal.component(.month, from: Date()))
        self.cities = CityCatalog.cities(for: countryCode)
    }

    private var monthSymbols: [String] { Calendar.current.shortMonthSymbols }

    var body: some View {
        VStack(spacing: 14) {
            Text("你哪一年去的 \(countryName)？")
                .font(Typo.serif(20)).foregroundStyle(Color.text)
                .multilineTextAlignment(.center).padding(.top, 8)

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

            Button { onConfirm(year, month, Array(selectedCities)) } label: {
                Text(buttonTitle).font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(LinearGradient.neonH, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24).padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .background(Color.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
            .frame(maxHeight: 200)
        }
    }
}

// MARK: - 去过的城市记录（hub 内 push）

/// 看看在某个国家实际去过哪些城市的记录（来自已点亮足迹）。
private struct CountryCitiesList: View {
    let countryCode: String
    let countryName: String
    let footprints: [Footprint]     // 已过滤到该国

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
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
