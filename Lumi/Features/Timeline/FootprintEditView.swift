import SwiftUI
import SwiftData

/// 足迹编辑：改 地点名 / 日期（开始 + 可选结束）/ 心情 / 同行人。
/// 位置与国家码不在此改（改坐标要重判定，超出编辑范围）。
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

    init(footprint: Footprint) {
        self.footprint = footprint
        _place = State(initialValue: footprint.placeName)
        _mood = State(initialValue: footprint.mood)
        _visitedAt = State(initialValue: footprint.visitedAt)
        _endedAt = State(initialValue: footprint.endedAt ?? footprint.visitedAt)
        _multiDay = State(initialValue: footprint.endedAt != nil)
        _companions = State(initialValue: footprint.companions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    placeSection
                    dateSection
                    moodSection
                    companionsSection
                    Color.clear.frame(height: 60)
                }
                .padding(Metrics.pad)
            }
            .background(Color.ink.ignoresSafeArea())
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
    }

    // MARK: - 地点名

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("地点名", systemImage: "mappin.and.ellipse")
            TextField("地点名", text: $place)
                .foregroundStyle(Color.textPrimary)
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
        }
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
