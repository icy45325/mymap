import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import CoreLocation

/// 足迹编辑：改 地点名 / 真实定位（国家城市随之关联）/ 日期 / 心情 / 同行人。
struct FootprintEditView: View {

    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var place: String
    @State private var mood: String
    @State private var visitedAt: Date
    @State private var endedAt: Date
    @State private var multiDay: Bool
    @State private var companions: [String]
    @State private var companionDraft = ""
    @State private var photoIDs: [String]
    @State private var means: PostcardStamp
    @State private var pickerItems: [PhotosPickerItem] = []

    // 真实地点重新定位（与创建时同口径：搜索 → 离线 Boundaries 定国家/酋长国）
    @StateObject private var search = PlaceSearchService()
    @State private var query = ""
    @State private var picked: PickedPlace?

    /// 选定的真实地点（保存时一并写回坐标 / 城市 / 国家码）。
    private struct PickedPlace {
        var name: String
        var cityName: String?
        var countryCode: String?
        var subRegionCode: String?
        var coordinate: CLLocationCoordinate2D
    }

    init(footprint: Footprint) {
        self.footprint = footprint
        _place = State(initialValue: footprint.placeName)
        _mood = State(initialValue: footprint.mood)
        _visitedAt = State(initialValue: footprint.visitedAt)
        _endedAt = State(initialValue: footprint.endedAt ?? footprint.visitedAt)
        _multiDay = State(initialValue: footprint.endedAt != nil)
        _companions = State(initialValue: footprint.companions)
        _photoIDs = State(initialValue: footprint.photoAssetIDs)
        _means = State(initialValue: PostcardStamp(rawValue: footprint.entryMeans) ?? .air)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    placeSection
                    photosSection
                    dateSection
                    transportSection
                    moodSection
                    companionsSection
                    Color.clear.frame(height: 60)
                }
                .padding(Metrics.pad)
            }
            .background(Color.ink.opacity(0.78).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("编辑足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundStyle(Color.litGlow)
                        .disabled(place.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.litGlow)
        .presentationBackground(.ultraThinMaterial)   // 背景虚化，编辑面板悬浮前置（#7）
        .presentationCornerRadius(28)
    }

    // MARK: - 地点名

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("地点名", systemImage: "mappin.and.ellipse")
            TextField("地点名", text: $place)
                .foregroundStyle(Color.textPrimary)
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))

            // 重新定位真实地点（关联国家 / 城市）
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.textMuted)
                TextField("搜索真实地点，重新定位", text: $query)
                    .foregroundStyle(Color.textPrimary)
                    .onChange(of: query) { _, q in search.search(q, near: currentRegion) }
                if search.isSearching { ProgressView().tint(Color.litGlow).scaleEffect(0.7) }
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))

            if !search.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(search.results.prefix(5)) { r in
                        Button { choose(r) } label: {
                            HStack {
                                Image(systemName: "mappin.circle").foregroundStyle(Color.textMuted)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name).foregroundStyle(Color.textPrimary).lineLimit(1)
                                    if !r.subtitle.isEmpty {
                                        Text(r.subtitle).font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 9).padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.lineSoft)
                    }
                }
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
            }

            if let p = picked {
                Label("已定位：\(locText(p))", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11.5)).foregroundStyle(Color.litGlow)
            }
        }
    }

    private var currentRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: footprint.coordinate,
                           span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6))
    }

    private func locText(_ p: PickedPlace) -> String {
        [p.cityName, CountryInfo.localizedName(for: p.countryCode)].compactMap { $0 }.joined(separator: " · ")
    }

    /// 选定真实地点：国家 / 酋长国以离线 Boundaries 为准，退回搜索结果自带码。
    private func choose(_ r: PlaceResult) {
        let cc = Boundaries.shared.countryCode(at: r.coordinate) ?? r.countryCode
        picked = PickedPlace(name: r.name, cityName: r.cityName, countryCode: cc,
                             subRegionCode: cc == "AE" ? Boundaries.shared.emirateCode(at: r.coordinate) : nil,
                             coordinate: r.coordinate)
        place = r.name
        query = ""
        search.clear()
    }

    // MARK: - 照片（增加 / 删除 / 替换，最多 21 张）

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("照片", systemImage: "photo.on.rectangle")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photoIDs, id: \.self) { id in
                        ZStack(alignment: .topTrailing) {
                            AssetImage(assetID: id, targetSize: CGSize(width: 200, height: 200))
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Button { photoIDs.removeAll { $0 == id } } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white, .black.opacity(0.55))
                            }
                            .padding(3)
                        }
                    }
                    if photoIDs.count < Footprint.maxPhotos {
                        PhotosPicker(selection: $pickerItems,
                                     maxSelectionCount: Footprint.maxPhotos - photoIDs.count,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("增加")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.litGlow)
                            .frame(width: 84, height: 84)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.line, style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }
                    }
                }
            }
            Text("最多 \(Footprint.maxPhotos) 张 · 已选 \(photoIDs.count)")
                .font(.system(size: 11)).foregroundStyle(Color.textSecondary)
        }
        .onChange(of: pickerItems) { _, items in Task { await mergePicked(items) } }
    }

    /// 把刚选的照片并入（不超过上限），随后清空选择器。
    /// 照片**拷贝进 App 沙盒**（LocalPhotoStore）——不依赖相册权限，limited 下也能显示；
    /// 拿不到数据时回退存相册引用。删除/取消编辑产生的孤儿文件由启动清理兜底。
    private func mergePicked(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            guard photoIDs.count < Footprint.maxPhotos else { break }
            let data = try? await item.loadTransferable(type: Data.self)
            guard let id = data.flatMap({ LocalPhotoStore.save($0) }) ?? item.itemIdentifier,
                  !photoIDs.contains(id) else { continue }
            photoIDs.append(id)
        }
        pickerItems = []
    }

    // MARK: - 日期

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("日期", systemImage: "calendar")
            VStack(spacing: 10) {
                dateRow("开始") {
                    DatePicker("", selection: $visitedAt, in: ...Date.now, displayedComponents: .date)
                        .onChange(of: visitedAt) { _, start in
                            if endedAt < start { endedAt = start }
                        }
                }
                Divider().overlay(Color.lineSoft)
                Toggle("多天行程", isOn: $multiDay)
                    .font(.subheadline).foregroundStyle(Color.textSecondary)
                    .tint(Color.litGlow)
                if multiDay {
                    Divider().overlay(Color.lineSoft)
                    dateRow("结束") {
                        DatePicker("", selection: $endedAt, in: visitedAt...Date.now, displayedComponents: .date)
                    }
                }
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
        }
    }

    private func dateRow<Picker: View>(_ label: LocalizedStringKey, @ViewBuilder _ picker: () -> Picker) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Color.textSecondary)
            Spacer()
            picker()
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.litGlow)
        }
    }

    // MARK: - 交通方式（图标切换）

    private var transportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("交通方式", systemImage: "stamp")
            HStack(spacing: 10) {
                ForEach(PostcardStamp.allCases) { m in
                    let active = m == means
                    Button { means = m; Haptics.selection() } label: {
                        VStack(spacing: 5) {
                            Image(systemName: m.motif).font(.system(size: 18, weight: .semibold))
                            Text(m.label).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(active ? .white : Color.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(active ? AnyShapeStyle(LinearGradient.neonH) : AnyShapeStyle(Color.panel),
                                    in: RoundedRectangle(cornerRadius: Metrics.radius))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.radius)
                            .stroke(active ? Color.clear : Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
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

    // MARK: - 动作

    private func addCompanion() {
        let name = companionDraft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !companions.contains(name) else { return }
        companions.append(name)
        companionDraft = ""
    }

    private func save() {
        let trimmedPlace = place.trimmingCharacters(in: .whitespaces)
        guard !trimmedPlace.isEmpty else { return }

        // 合并未提交的同行人草稿（打了字没点 + / 回车也不丢）
        let pending = companionDraft.trimmingCharacters(in: .whitespaces)
        let finalCompanions = (companions + (pending.isEmpty ? [] : [pending]))
            .reduce(into: [String]()) { acc, name in if !acc.contains(name) { acc.append(name) } }

        footprint.placeName = trimmedPlace
        footprint.mood = mood.trimmingCharacters(in: .whitespaces)
        footprint.visitedAt = visitedAt
        footprint.endedAt = (multiDay && endedAt > visitedAt) ? endedAt : nil
        footprint.companions = finalCompanions
        footprint.photoAssetIDs = Array(photoIDs.prefix(Footprint.maxPhotos))
        footprint.entryMeans = means.rawValue

        // 若重新定位了真实地点：一并写回坐标 / 城市 / 国家码（与创建同口径）
        if let p = picked {
            footprint.latitude = p.coordinate.latitude
            footprint.longitude = p.coordinate.longitude
            footprint.cityName = p.cityName
            footprint.countryCode = p.countryCode
            footprint.subRegionCode = p.subRegionCode
        }
        footprint.updatedAt = .now   // 云同步 LWW 判定
        try? context.save()

        WidgetSync.refresh(context)   // 日期改动可能影响「去年今日」/ 最近一次
        dismiss()
    }

    // MARK: - 小工具

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title.localized, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.textSecondary)
    }
}
