import SwiftUI
import SwiftData

/// 星迹时间轴（§4.3）· 暗夜霓虹 v2。
/// 倒序卡片流 + 地区筛选 + 年份分组；支持删除（§10③，长按卡片）。
struct TimelineView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    @State private var regionFilter: RegionFilter = .all
    @State private var pendingDelete: Footprint?

    private enum RegionFilter: Hashable { case all, region(Region) }

    var body: some View {
        NavigationStack {
            Group {
                if footprints.isEmpty { emptyState }
                else { content }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .onAppear { Analytics.log(.timelineViewed(footprintCount: footprints.count)) }
        .confirmationDialog("删除这条足迹？", isPresented: showDeleteDialog, titleVisibility: .visible) {
            Button("删除", role: .destructive) { confirmDelete() }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - 内容

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                SegmentBar(items: segmentItems, selection: $regionFilter)
                    .padding(.top, 14).padding(.bottom, 6)
                timeline
                Color.clear.frame(height: 24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Footprints").font(Typo.serif(27))
                Text(statLine).font(.system(size: 11)).tracking(1.2).foregroundStyle(Color.faint)
            }
            Spacer()
        }
        .padding(.horizontal, 26).padding(.top, 16)
    }

    /// 时间线主体：按年份分组，每条带发光节点。
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groupedYears, id: \.year) { group in
                Text(String(group.year))
                    .font(Typo.serif(15)).foregroundStyle(Color.muted)
                    .padding(.leading, 26).padding(.top, 16).padding(.bottom, 10)
                ForEach(group.items) { fp in
                    TimelineItem(footprint: fp, isLatest: fp.id == footprints.first?.id)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)
                        .contextMenu {
                            Button(role: .destructive) { pendingDelete = fp } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(Color.nPurple)
            Text("还没有星迹").font(.headline).foregroundStyle(Color.text)
            Text("回地图点亮第一个地方").font(.subheadline).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 派生

    private var filtered: [Footprint] {
        switch regionFilter {
        case .all: return footprints
        case .region(let r): return footprints.filter { $0.region == r }
        }
    }

    private var groupedYears: [(year: Int, items: [Footprint])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { cal.component(.year, from: $0.visitedAt) }
        return groups.keys.sorted(by: >).map { (year: $0, items: groups[$0] ?? []) }
    }

    /// 分段：全部 + 实际出现过的地区。
    private var segmentItems: [(value: RegionFilter, label: String)] {
        let present = Region.allCases.filter { r in footprints.contains { $0.region == r } }
        return [(.all, "全部")] + present.map { (.region($0), $0.displayName) }
    }

    private var statLine: String {
        let year = Calendar.current.component(.year, from: footprints.first?.visitedAt ?? .now)
        return "\(year) · 已记录 \(footprints.count) 段"
    }

    // MARK: - 删除

    private var showDeleteDialog: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
    private func confirmDelete() {
        guard let fp = pendingDelete else { return }
        context.delete(fp)               // Card 随 cascade 删除
        try? context.save()
        pendingDelete = nil
    }
}

// MARK: - 时间线条目

private struct TimelineItem: View {
    let footprint: Footprint
    let isLatest: Bool

    private static let dateFormat: Date.FormatStyle = .dateTime.year().month(.abbreviated).day()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 节点 + 竖线
            VStack(spacing: 0) {
                ZStack {
                    if isLatest {
                        Circle().fill(Color.nPink).frame(width: 13, height: 13)
                            .shadow(color: .nPink, radius: 8)
                    } else {
                        Circle().stroke(Color.nPurple, lineWidth: 2).frame(width: 13, height: 13)
                            .background(Circle().fill(Color.bg))
                    }
                }
                .padding(.top, 6)
                Rectangle().fill(Color.line).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 13)
            .padding(.trailing, 16)

            NavigationLink {
                FootprintDetailView(footprint: footprint)
            } label: {
                card
            }
            .buttonStyle(.plain)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(footprint.visitedAt.formatted(Self.dateFormat))
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
                if isLatest {
                    Text("最新").font(.system(size: 9, weight: .bold)).tracking(1)
                        .foregroundStyle(Color.nPink)
                }
            }
            ZStack(alignment: .bottomLeading) {
                AssetImage(assetID: footprint.photoAssetIDs.first,
                           targetSize: CGSize(width: 700, height: 500))
                    .frame(maxWidth: .infinity).frame(height: 172).clipped()
                LinearGradient(colors: [.clear, Color.bg.opacity(0.86)],
                               startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(footprint.flag).font(.system(size: 16))
                        Text(footprint.title).font(Typo.serif(19)).foregroundStyle(.white)
                    }
                    HStack(spacing: 10) {
                        Text(footprint.locationSubtitle)
                            .font(.system(size: 11)).foregroundStyle(Color(hex: 0xC9C2D6))
                        if footprint.photoCount > 0 {
                            Label("\(footprint.photoCount)", systemImage: "camera.fill")
                                .font(.system(size: 11)).foregroundStyle(.white)
                                .padding(.vertical, 4).padding(.horizontal, 10)
                                .background(.black.opacity(0.42), in: Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
                        }
                    }
                }
                .padding(16)
            }
            .frame(height: 172)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(isLatest ? Color.nPink.opacity(0.5) : Color.line, lineWidth: 1))
        }
    }
}
