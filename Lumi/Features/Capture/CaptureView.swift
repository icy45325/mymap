import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import CoreLocation

/// 录入·明信片卡（§4.2）。单屏完成：照片 → 地点 → 日期 → 心情 → 同行人 →「点亮这里」。
///
/// 录入状态机（§5.2）：Draft →（填充）→ Filling →（点亮这里）→ Saved；中途退出 → Discarded。
struct CaptureView: View {

    /// 入口来源（埋点 source）：map（点屏带坐标进来）/ fab。
    let source: String
    /// 地图点屏带进来的坐标（可空：从 FAB 进来则为空，靠搜索/定位选点）。
    let prefilledCoordinate: CLLocationCoordinate2D?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// 用于判断"点亮的是不是新国家"（§5.1 计数口径）。
    @Query private var footprints: [Footprint]

    // MARK: - 选中地点
    private struct SelectedPlace {
        var name: String
        var cityName: String?
        var countryCode: String?
        var subRegionCode: String?
        var coordinate: CLLocationCoordinate2D

        /// 由坐标 + 候选国家码组装：国家 / 酋长国以离线 Boundaries 为准（§5.1），
        /// 离线判定不到时退回候选码（如搜索结果自带的 isoCountryCode）。
        init(name: String, cityName: String?, countryCode candidate: String?,
             coordinate: CLLocationCoordinate2D) {
            self.name = name
            self.cityName = cityName
            self.coordinate = coordinate
            let resolved = Boundaries.shared.countryCode(at: coordinate) ?? candidate
            self.countryCode = resolved
            self.subRegionCode = resolved == "AE"
                ? Boundaries.shared.emirateCode(at: coordinate)
                : nil
        }

        /// 二级描述：城市 · 国家。
        var subtitle: String {
            [cityName, Locale.current.localizedString(forRegionCode: countryCode ?? "")]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }
    @State private var selected: SelectedPlace?
    @State private var resolvingPrefill = false

    // MARK: - 表单字段
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: Image?
    @State private var photoAssetID: String?
    @State private var visitedAt: Date = .now
    @State private var endedAt: Date = .now
    @State private var mood: String = ""
    @State private var companions: [String] = []
    @State private var companionDraft: String = ""

    // MARK: - 地点搜索
    @StateObject private var search = PlaceSearchService()
    @StateObject private var location = LocationService()
    @State private var query: String = ""

    // MARK: - 状态机
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    photoSection
                    placeSection
                    dateSection
                    moodSection
                    companionsSection
                    Color.clear.frame(height: 80)   // 给底部主按钮留白
                }
                .padding(Metrics.pad)
            }
            .background(Color.ink.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                lightUpButton
                    .ignoresSafeArea(.keyboard, edges: .bottom)   // 键盘弹出不顶起主按钮
            }
            .navigationTitle("新足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.litGlow)
        .task { await onAppear() }
        .onDisappear(perform: onDisappear)
    }

    // MARK: - 照片（16:9 中心裁剪，不溢出）
    private var photoSection: some View {
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                Color.panel
                if let photoPreview {
                    photoPreview
                        .resizable()
                        .scaledToFill()          // 中心裁剪填满 16:9 框，溢出由容器 clip
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.litGlow)
                        Text("加一张照片（可跳过）")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius).stroke(Color.line, lineWidth: 1))
        }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    // MARK: - 地点
    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("地点", systemImage: "mappin.and.ellipse")

            if let selected {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.litGlow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.name).foregroundStyle(Color.textPrimary)
                        if !selected.subtitle.isEmpty {
                            Text(selected.subtitle).font(.caption).foregroundStyle(Color.textSecondary)
                        }
                    }
                    Spacer()
                    Button("更改") { self.selected = nil }
                        .font(.caption).foregroundStyle(Color.litGlow)
                }
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
            } else {
                searchField
                if search.isSearching {
                    ProgressView().tint(Color.litGlow).padding(.vertical, 4)
                }
                ForEach(search.results) { result in
                    Button { choose(result) } label: {
                        HStack {
                            Image(systemName: "mappin.circle").foregroundStyle(Color.textMuted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).foregroundStyle(Color.textPrimary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle).font(.caption).foregroundStyle(Color.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    Divider().overlay(Color.lineSoft)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.textMuted)
            TextField("搜索地点", text: $query)
                .foregroundStyle(Color.textPrimary)
                .onChange(of: query) { _, q in
                    search.search(q, near: searchRegion)
                }
            Button {
                Task { await useCurrentLocation() }
            } label: {
                Image(systemName: "location.fill").foregroundStyle(Color.litGlow)
            }
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
    }

    // MARK: - 日期（开始 / 结束，可选一段时间）
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("日期", systemImage: "calendar")
            VStack(spacing: 10) {
                dateRow("开始") {
                    DatePicker("", selection: $visitedAt, in: ...Date.now, displayedComponents: .date)
                        .onChange(of: visitedAt) { _, start in
                            if endedAt < start { endedAt = start }   // 结束不早于开始
                        }
                }
                Divider().overlay(Color.lineSoft)
                dateRow("结束") {
                    DatePicker("", selection: $endedAt, in: visitedAt...Date.now, displayedComponents: .date)
                }
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
        }
    }

    private func dateRow<Picker: View>(_ label: String, @ViewBuilder _ picker: () -> Picker) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Color.textSecondary)
            Spacer()
            picker()
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.litGlow)
        }
    }

    // MARK: - 心情
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("一句心情", systemImage: "text.quote")
            TextField("记一句此刻的感受…", text: $mood, axis: .vertical)
                .lineLimit(1...3)
                .foregroundStyle(Color.textPrimary)
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
        }
    }

    // MARK: - 同行人
    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("同行人", systemImage: "person.2")
            if !companions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(companions, id: \.self) { name in
                            HStack(spacing: 6) {
                                Text(name).font(.subheadline).foregroundStyle(Color.textPrimary)
                                Button { companions.removeAll { $0 == name } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textMuted)
                                }
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.panel, in: Capsule())
                            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("和谁一起？", text: $companionDraft)
                    .foregroundStyle(Color.textPrimary)
                    .onSubmit(addCompanion)
                Button(action: addCompanion) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.litGlow)
                }
                .disabled(companionDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
        }
    }

    // MARK: - 主按钮
    private var lightUpButton: some View {
        Button(action: lightUp) {
            Text("点亮这里 ✦")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.neonH, in: Capsule())
                .foregroundStyle(.white)
                .opacity(canLightUp ? 1 : 0.4)
                .shadow(color: Color.nPurple.opacity(0.5), radius: 12)
        }
        .disabled(!canLightUp)
        .padding(.horizontal, Metrics.pad)
        .padding(.bottom, 8)
        .background(Color.ink.opacity(0.0))
    }

    // MARK: - 派生

    /// 能点亮：已有选中地点（搜索/定位选定，或点屏坐标已反解出来）。
    private var canLightUp: Bool { selected != nil }

    private var searchRegion: MKCoordinateRegion? {
        guard let c = selected?.coordinate ?? prefilledCoordinate else { return nil }
        return MKCoordinateRegion(center: c,
                                  span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4))
    }

    private var filledFields: Int {
        var n = 0
        if photoAssetID != nil { n += 1 }
        if selected != nil { n += 1 }
        if !mood.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        if !companions.isEmpty { n += 1 }
        return n
    }

    // MARK: - 动作

    private func onAppear() async {
        Analytics.log(.captureStarted(source: source))
        // 点屏带坐标进来 → 反向地理编码，预填地点
        if let c = prefilledCoordinate, selected == nil {
            resolvingPrefill = true
            if let place = await Geocoding.resolve(c) {
                selected = SelectedPlace(name: place.placeName,
                                         cityName: place.cityName,
                                         countryCode: place.countryCode,
                                         coordinate: c)
            } else {
                // 反解失败也允许点亮：用坐标兜底（§7）
                selected = SelectedPlace(name: "标记的地点", cityName: nil,
                                         countryCode: nil, coordinate: c)
            }
            resolvingPrefill = false
        }
    }

    private func onDisappear() {
        if !saved {
            Analytics.log(.captureAbandoned(filledFields: filledFields))
        }
    }

    private func choose(_ result: PlaceResult) {
        selected = SelectedPlace(name: result.name,
                                 cityName: result.cityName,
                                 countryCode: result.countryCode,
                                 coordinate: result.coordinate)
        query = ""
        search.clear()
    }

    private func useCurrentLocation() async {
        guard let c = await location.requestOnce() else { return }
        if let place = await Geocoding.resolve(c) {
            selected = SelectedPlace(name: place.placeName,
                                     cityName: place.cityName,
                                     countryCode: place.countryCode,
                                     coordinate: c)
        } else {
            selected = SelectedPlace(name: "我的位置", cityName: nil,
                                     countryCode: nil, coordinate: c)
        }
    }

    private func addCompanion() {
        let name = companionDraft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !companions.contains(name) else { return }
        companions.append(name)
        companionDraft = ""
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        photoAssetID = item.itemIdentifier
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            photoPreview = Image(uiImage: uiImage)
        }
    }

    /// 「点亮这里」：落库 Footprint + Card，触发地图点亮与计数（§4.2 / §5.2 Saved）。
    private func lightUp() {
        guard let selected else { return }

        // 点亮前的已有国家集合，用于判断"新国家"（§5.1）
        let priorCodes = Set(footprints.compactMap { $0.countryCode })

        // 合并未提交的同行人草稿（用户打了字但没点「+」/回车也不丢）
        let pending = companionDraft.trimmingCharacters(in: .whitespaces)
        let finalCompanions = (companions + (pending.isEmpty ? [] : [pending]))
            .reduce(into: [String]()) { acc, name in if !acc.contains(name) { acc.append(name) } }

        let footprint = Footprint(
            placeName: selected.name,
            coordinate: selected.coordinate,
            cityName: selected.cityName,
            visitedAt: visitedAt,
            endedAt: endedAt > visitedAt ? endedAt : nil,   // 仅多天时记录结束日
            mood: mood.trimmingCharacters(in: .whitespaces),
            companions: finalCompanions,
            photoAssetIDs: photoAssetID.map { [$0] } ?? []
        )
        footprint.countryCode = selected.countryCode
        footprint.subRegionCode = selected.subRegionCode
        context.insert(footprint)
        context.insert(Card(footprint: footprint))     // §4.2：同步持久化一张明信片卡
        try? context.save()

        WidgetSync.refresh(context)                     // 点亮后对齐主屏小组件计数
        if (footprint.countryCode ?? "").isEmpty {      // 离线缝隙没判定到国家 → 在线兜底补全
            Task { await FootprintRepair.backfillMissingCountries(context) }
        }

        saved = true
        Analytics.log(.footprintCreated(countryCode: footprint.countryCode,
                                        hasPhoto: photoAssetID != nil,
                                        companionsCount: finalCompanions.count))
        if let code = footprint.countryCode, !priorCodes.contains(code) {
            Analytics.log(.countryLit(countryCode: code, totalLit: priorCodes.count + 1))
        }
        dismiss()
    }

    // MARK: - 小工具
    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title.localized, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.textSecondary)
    }
}
