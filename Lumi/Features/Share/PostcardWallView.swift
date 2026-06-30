import SwiftUI
import SwiftData

/// 明信片墙：只收藏**收到的**明信片（扫码 / 链接 / 隔空投送收到的）。
/// 自己点亮的足迹不是明信片；自己寄出的（按明信片逻辑）自己也看不到。
struct PostcardWallView: View {
    @Query(sort: \Footprint.createdAt, order: .reverse) private var footprints: [Footprint]
    @ObservedObject private var contacts = PostcardContacts.shared
    @State private var selected: Footprint?
    @State private var showScanner = false
    @State private var sort: WallSort = .received

    enum WallSort: String, CaseIterable, Identifiable {
        case received, place
        var id: String { rawValue }
        var label: LocalizedStringKey { self == .received ? "按接收时间" : "按来源地 A–Z" }
    }

    private var items: [Footprint] {
        let received = footprints.filter { $0.isReceived }
        switch sort {
        case .received:   // 接收时间倒序（无 receivedAt 的旧数据用 createdAt 兜底）
            return received.sorted { ($0.receivedAt ?? $0.createdAt) > ($1.receivedAt ?? $1.createdAt) }
        case .place:      // 来源地 A→Z
            return received.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if items.isEmpty && contacts.recent.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !items.isEmpty { countStat }
                        if !contacts.recent.isEmpty { contactsStrip }
                        if items.isEmpty {
                            Text("还没有收到明信片").font(.subheadline).foregroundStyle(Color.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 28)
                        } else {
                            if items.count > 1 {
                                Picker("", selection: $sort) {
                                    ForEach(WallSort.allCases) { Text($0.label).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                            LazyVGrid(columns: cols, spacing: 12) {
                                ForEach(items) { fp in
                                    Button { selected = fp } label: { PostcardCell(footprint: fp) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("明信片墙")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showScanner = true } label: {
                    Label("扫码收明信片", systemImage: "qrcode.viewfinder")
                }
                .tint(Color.nCyan)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $selected) { ReceivedPostcardSheet(footprint: $0) }
        .sheet(isPresented: $showScanner) { ScannerSheet() }
    }

    /// 明信片墙统计：已收到的明信片数量（+ 往来的人数）。
    private var countStat: some View {
        HStack(spacing: 10) {
            statCard("\(items.count)", "收到的明信片")
            if !contacts.recent.isEmpty { statCard("\(contacts.recent.count)", "往来的人") }
        }
    }

    private func statCard(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(Typo.serif(26)).foregroundStyle(Color.text)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    /// 往来的人（本地 social-lite）：收 / 发明信片攒下的昵称头像横条。
    private var contactsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("往来的人").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(contacts.recent) { c in
                        VStack(spacing: 5) {
                            ZStack {
                                Circle().fill(LinearGradient.neon).frame(width: 46, height: 46)
                                    .overlay(Circle().stroke(Color.line, lineWidth: 1))
                                Text(String(c.name.prefix(1))).font(Typo.serif(18)).foregroundStyle(.white)
                            }
                            Text(c.name).font(.system(size: 10)).foregroundStyle(Color.muted)
                                .lineLimit(1).frame(width: 52)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack").font(.system(size: 44)).foregroundStyle(Color.nPink)
            Text("还没有收到明信片").font(.headline).foregroundStyle(Color.text)
            Text("朋友用扫码 / 链接 / 隔空投送寄来的明信片，会收进这里")
                .font(.subheadline).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 查看收到的明信片：只翻转 + 分享（系统 / Instagram），无样式 / 邮票 / 编辑功能。
private struct ReceivedPostcardSheet: View {
    let footprint: Footprint
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @State private var flipped = false
    @State private var cover: UIImage?
    @State private var shareImage: Image?

    private var style: PostcardStyle { PostcardStyle(rawValue: footprint.postcardStyle) ?? .vintage }
    private var stamp: PostcardStamp { PostcardStamp(rawValue: footprint.stampStyle) ?? .air }
    private var dateText: String { footprint.visitSpanText() }
    private var sender: String { footprint.senderName ?? "" }

    private var exportCard: PostcardExportCard {
        PostcardExportCard(footprint: footprint, cover: cover, message: footprint.mood,
                           recipient: holderName, style: style, stamp: stamp,
                           watermark: true, sender: sender, dateText: dateText, showPostmark: true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PostcardFlipCard(footprint: footprint, cover: cover, message: footprint.mood,
                                     recipient: holderName, style: style, stamp: stamp, flipped: flipped,
                                     sender: sender, dateText: dateText, showPostmark: true)
                        .onTapGesture { withAnimation { flipped.toggle() } }

                    Button { withAnimation { flipped.toggle() } } label: {
                        Label("翻面", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                            .padding(.vertical, 9).padding(.horizontal, 18)
                            .background(Color.panel, in: Capsule())
                            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                    }

                    if let shareImage {
                        HStack(spacing: 10) {
                            ShareLink(item: shareImage, preview: SharePreview(footprint.title, image: shareImage)) {
                                Label("分享", systemImage: "square.and.arrow.up")
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                                    .background(LinearGradient.neonH, in: Capsule()).foregroundStyle(.white)
                            }
                            InstagramShareButton { ShareRender.uiImage(exportCard, scale: 4) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                    } else {
                        ProgressView().tint(Color.nPink).padding(.vertical, 14)
                    }
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("明信片").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            if let d = footprint.receivedCoverData { cover = UIImage(data: d) }
            shareImage = ShareRender.image(exportCard, scale: 3)
        }
    }
}

/// 明信片墙单元：封面（照片或霓虹渐变）+ 手写寄语片段 + 地点；收到的标「✦ 收到」。
private struct PostcardCell: View {
    let footprint: Footprint

    private var style: PostcardStyle { PostcardStyle(rawValue: footprint.postcardStyle) ?? .vintage }
    private var stamp: PostcardStamp { PostcardStamp(rawValue: footprint.stampStyle) ?? .air }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = footprint.receivedCoverData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else if let id = footprint.photoAssetIDs.first {
                    AssetImage(assetID: id, targetSize: CGSize(width: 600, height: 800))
                } else {
                    LinearGradient(colors: PostcardTheme.make(style).photo,
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
        .overlay(alignment: .topLeading) {
            PostcardStampView(stamp: stamp, mini: true).frame(width: 26, height: 31).padding(8)
        }
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
