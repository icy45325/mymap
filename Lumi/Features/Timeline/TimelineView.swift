import SwiftUI
import SwiftData

/// 足迹时间轴（§4.3）：倒序卡片流，回顾入口。支持删除（§10③）。
struct TimelineView: View {

    @Environment(\.modelContext) private var context

    /// 倒序（visitedAt desc）。
    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    @State private var pendingDelete: Footprint?

    private static let dateFormat: Date.FormatStyle =
        .dateTime.year().month(.abbreviated).day()

    var body: some View {
        NavigationStack {
            Group {
                if footprints.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.litGlow)
        .onAppear { Analytics.log(.timelineViewed(footprintCount: footprints.count)) }
        .confirmationDialog("删除这条足迹？", isPresented: showDeleteDialog, titleVisibility: .visible) {
            Button("删除", role: .destructive) { confirmDelete() }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - 列表

    private var list: some View {
        List {
            Section {
                ForEach(footprints) { footprint in
                    NavigationLink {
                        FootprintDetailView(footprint: footprint)
                    } label: {
                        TimelineRow(footprint: footprint, dateFormat: Self.dateFormat)
                    }
                    .listRowBackground(Color.panel)
                    .listRowSeparatorTint(Color.lineSoft)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { pendingDelete = footprint } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(statLine).font(Typo.mono(12)).foregroundStyle(Color.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map").font(.system(size: 44)).foregroundStyle(Color.textMuted)
            Text("还没有足迹").font(.headline).foregroundStyle(Color.textSecondary)
            Text("回地图点亮第一个地方").font(.subheadline).foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 顶部统计行：`{年份} · 已记录 {n} 段`（§11 #9）。
    private var statLine: String {
        let year = Calendar.current.component(.year, from: footprints.first?.visitedAt ?? .now)
        return "\(year) · 已记录 \(footprints.count) 段"
    }

    // MARK: - 删除

    private var showDeleteDialog: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func confirmDelete() {
        guard let footprint = pendingDelete else { return }
        context.delete(footprint)        // Card 随 cascade 一并删除
        try? context.save()              // 地图着色与计数随 @Query 自动同步（§10③）
        pendingDelete = nil
    }
}

// MARK: - 行

private struct TimelineRow: View {
    let footprint: Footprint
    let dateFormat: Date.FormatStyle

    var body: some View {
        HStack(spacing: 12) {
            AssetImage(assetID: footprint.photoAssetIDs.first, targetSize: CGSize(width: 140, height: 140))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(footprint.placeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(footprint.visitedAt.formatted(dateFormat))
                    .font(.caption).foregroundStyle(Color.textSecondary)
                if !footprint.companions.isEmpty {
                    Label(footprint.companions.joined(separator: "、"),
                          systemImage: "person.2")
                        .font(.caption2).foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
