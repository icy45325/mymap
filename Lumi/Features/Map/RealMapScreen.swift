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

    @State private var tapped: TappedPlace?
    @State private var yearPickFor: TappedPlace?

    fileprivate struct TappedPlace: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let countryCode: String
        var countryName: String { CountryInfo.localizedName(for: countryCode) ?? String(localized: "这个国家") }
    }

    private var litCountryCodes: Set<String> { Set(footprints.compactMap { $0.countryCode }) }
    private var litEmirateCodes: Set<String> { Set(footprints.compactMap { $0.subRegionCode }) }

    private var renderState: MapRenderState {
        MapRenderState(
            litRegions: Boundaries.shared.regions(forCountryCodes: litCountryCodes,
                                                  emirateCodes: litEmirateCodes),
            pins: footprints.map { MapPin(id: $0.id, coordinate: $0.coordinate) },
            onTapCoordinate: handleTap)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.bg.ignoresSafeArea()
            provider.makeMapView(renderState).ignoresSafeArea()
            hint
            closeButton.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(tapped?.countryName ?? "", isPresented: tappedDialog,
                            titleVisibility: .visible, presenting: tapped) { place in
            Button(litCountryCodes.contains(place.countryCode) ? "已点亮 · 再记一次" : "我去过这里 ✦") {
                tapped = nil
                yearPickFor = place
            }
            Button("加入心愿单") { addWish(place); tapped = nil }
            Button("取消", role: .cancel) { tapped = nil }
        }
        .sheet(item: $yearPickFor) { place in
            VisitDetailsSheet(place: place) { year, month, city in
                lightCountry(place, year: year, month: month, city: city)
            }
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

    private func lightCountry(_ place: TappedPlace, year: Int, month: Int, city: PresetCity?) {
        let prior = Set(footprints.compactMap { $0.countryCode })
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()

        // 选了城市则用城市坐标/名字落点，否则以国家落点
        let coordinate = city?.coordinate ?? place.coordinate
        let footprint = Footprint(placeName: city?.name ?? place.countryName,
                                  coordinate: coordinate,
                                  cityName: city?.name,
                                  visitedAt: date)
        footprint.countryCode = place.countryCode
        if place.countryCode == "AE" {
            footprint.subRegionCode = Boundaries.shared.emirateCode(at: coordinate)
        }
        context.insert(footprint)
        context.insert(Card(footprint: footprint))
        try? context.save()

        Analytics.log(.footprintCreated(countryCode: place.countryCode, hasPhoto: false, companionsCount: 0))
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

/// 选择「哪年/哪月去的」+ 可选城市（默认折叠不选）——快速点亮用。
private struct VisitDetailsSheet: View {
    let place: RealMapScreen.TappedPlace
    let onPick: (_ year: Int, _ month: Int, _ city: PresetCity?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var month: Int
    @State private var selectedCity: PresetCity?
    @State private var citiesExpanded = false
    private let years: [Int]
    private let cities: [PresetCity]

    init(place: RealMapScreen.TappedPlace,
         onPick: @escaping (Int, Int, PresetCity?) -> Void) {
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

                Button { onPick(year, month, selectedCity); dismiss() } label: {
                    Text("点亮 ✦").font(.headline)
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
        .presentationDetents([.height(cities.isEmpty ? 360 : 470)])
        .preferredColorScheme(.dark)
    }

    /// 可选城市：默认折叠、不选中；点选某城高亮，再点取消。
    private var citySection: some View {
        DisclosureGroup(isExpanded: $citiesExpanded) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(cities) { city in
                        Button {
                            selectedCity = (selectedCity == city) ? nil : city
                        } label: {
                            HStack {
                                Text(city.name).foregroundStyle(Color.text)
                                Spacer()
                                if selectedCity == city {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.nPink)
                                }
                            }
                            .padding(.vertical, 9).padding(.horizontal, 12)
                            .background(selectedCity == city ? Color.nPink.opacity(0.14) : Color.panel,
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxHeight: 150)
        } label: {
            HStack {
                Text("城市（可选）").font(.subheadline).foregroundStyle(Color.muted)
                Spacer()
                if let c = selectedCity {
                    Text(c.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.nPink)
                }
            }
        }
        .tint(Color.muted)
        .padding(.horizontal, 8)
    }
}
