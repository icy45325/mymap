import SwiftUI
import SwiftData

/// 明信片墙：收藏所有明信片（自己点亮的 + 收到的），可筛选；点开可再分享。
struct PostcardWallView: View {
    @Query(sort: \Footprint.createdAt, order: .reverse) private var footprints: [Footprint]
    @State private var filter: Filter = .all
    @State private var selected: Footprint?

    private enum Filter: Hashable { case all, mine, received }

    private var items: [Footprint] {
        switch filter {
        case .all:      return footprints
        case .mine:     return footprints.filter { !$0.isReceived }
        case .received: return footprints.filter { $0.isReceived }
        }
    }
    private var segmentItems: [(value: Filter, label: String)] {
        [(.all, "全部"), (.mine, "我的"), (.received, "收到的")]
    }

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if footprints.isEmpty { empty }
            else {
                ScrollView {
                    SegmentBar(items: segmentItems, selection: $filter)
                        .padding(.top, 12).padding(.bottom, 4)
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(items) { fp in
                            Button { selected = fp } label: { PostcardCell(footprint: fp) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("明信片墙")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $selected) { PostcardSheet(footprint: $0) }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack").font(.system(size: 44)).foregroundStyle(Color.nPink)
            Text("还没有明信片").font(.headline).foregroundStyle(Color.text)
            Text("点亮足迹会生成明信片；收到的明信片也会收进这里")
                .font(.subheadline).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 明信片墙单元：封面（照片或霓虹渐变）+ 手写寄语片段 + 地点；收到的标「✦ 收到」。
private struct PostcardCell: View {
    let footprint: Footprint

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let id = footprint.photoAssetIDs.first {
                    AssetImage(assetID: id, targetSize: CGSize(width: 600, height: 800))
                } else {
                    LinearGradient(colors: [Color.nOrange.opacity(0.5), Color.nPink.opacity(0.45),
                                            Color.nPurple.opacity(0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Text(footprint.flag).font(.system(size: 64)).opacity(0.25))
                }
            }
            .aspectRatio(3.0/4.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                if !footprint.mood.isEmpty {
                    Text(footprint.mood).font(.handwriting(15)).foregroundStyle(.white)
                        .lineLimit(2)
                }
                HStack(spacing: 5) {
                    Text(footprint.flag).font(.system(size: 14))
                    Text(footprint.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if footprint.isReceived {
                Text("✦ 收到").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(Color.nPink.opacity(0.9), in: Capsule())
                    .padding(8)
            }
        }
    }
}
