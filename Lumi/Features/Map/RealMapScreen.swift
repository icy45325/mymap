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

    private struct TappedPlace: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let countryCode: String
        var countryName: String { CountryInfo.chineseName(for: countryCode) ?? "这个国家" }
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
            YearPickerSheet(country: place.countryName) { year in
                lightCountry(place, year: year)
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

    private func lightCountry(_ place: TappedPlace, year: Int) {
        let prior = Set(footprints.compactMap { $0.countryCode })
        let date = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()

        let footprint = Footprint(placeName: place.countryName,
                                  coordinate: place.coordinate,
                                  visitedAt: date)
        footprint.countryCode = place.countryCode
        if place.countryCode == "AE" {
            footprint.subRegionCode = Boundaries.shared.emirateCode(at: place.coordinate)
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
        // 已在心愿单则不重复
        let wish = Wish(placeName: place.countryName,
                        coordinate: place.coordinate,
                        countryCode: place.countryCode)
        context.insert(wish)
        try? context.save()
    }

    private var tappedDialog: Binding<Bool> {
        Binding(get: { tapped != nil }, set: { if !$0 { tapped = nil } })
    }
}

/// 选择「哪一年去的」——快速点亮用，年份决定它落在时间线的哪一年。
private struct YearPickerSheet: View {
    let country: String
    let onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    private let years: [Int]

    init(country: String, onPick: @escaping (Int) -> Void) {
        self.country = country
        self.onPick = onPick
        let current = Calendar.current.component(.year, from: Date())
        self.years = Array(stride(from: current, through: current - 60, by: -1))
        _year = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("你哪一年去的 \(country)？")
                    .font(Typo.serif(20)).foregroundStyle(Color.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Picker("", selection: $year) {
                    ForEach(years, id: \.self) { Text(verbatim: "\($0) 年").tag($0) }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                Button { onPick(year); dismiss() } label: {
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
        .presentationDetents([.height(340)])
        .preferredColorScheme(.dark)
    }
}
