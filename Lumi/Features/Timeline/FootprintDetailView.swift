import SwiftUI

/// 明信片卡详情（§4.3）· 暗夜霓虹 v2。支持编辑（地点名 / 日期 / 心情 / 同行人）。
struct FootprintDetailView: View {

    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showPostcard = false
    @State private var heroPage = 0

    private static let dateFormat: Date.FormatStyle = .dateTime.year().month(.wide).day()
    /// 多图自动翻页节拍。
    private let autoFlip = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 18) {
                    title
                    statRow
                    if !footprint.mood.isEmpty {
                        Text(footprint.mood)
                            .font(.system(size: 13.5)).lineSpacing(4)
                            .foregroundStyle(Color(hex: 0xC8C8DC))
                    }
                    infoRow("日期", footprint.visitSpanText(Self.dateFormat))
                    if !footprint.companions.isEmpty { companionsSection }
                    Button { showPostcard = true } label: {
                        Label("分享明信片", systemImage: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(LinearGradient.neonH, in: Capsule())
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 26)
                .padding(.top, 4)
                .offset(y: -46)
            }
        }
        .ignoresSafeArea(edges: .top)          // 顶部照片墙通栏，盖住 status bar 黑边
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) { backButton }
        .overlay(alignment: .topTrailing) { editButton }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEdit) {
            FootprintEditView(footprint: footprint)
        }
        .sheet(isPresented: $showPostcard) {
            PostcardSheet(footprint: footprint)
        }
    }

    private var editButton: some View {
        Button { showEdit = true } label: {
            Image(systemName: "square.and.pencil").font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.trailing, 18).padding(.top, 58)
    }

    private var heroHeight: CGFloat { 320 }   // 含 status bar 区域的通栏高度

    private var hero: some View {
        ZStack(alignment: .bottom) {
            Group {
                if footprint.photoAssetIDs.count > 1 {
                    // 多图：左右滑动 + 自动翻页 + 页码圆点
                    TabView(selection: $heroPage) {
                        ForEach(Array(footprint.photoAssetIDs.enumerated()), id: \.offset) { idx, id in
                            AssetImage(assetID: id, targetSize: CGSize(width: 1200, height: 900))
                                .frame(maxWidth: .infinity).frame(height: heroHeight).clipped()
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                    .onReceive(autoFlip) { _ in
                        let count = footprint.photoAssetIDs.count
                        guard count > 1 else { return }
                        withAnimation(.easeInOut(duration: 0.6)) { heroPage = (heroPage + 1) % count }
                    }
                } else {
                    AssetImage(assetID: footprint.photoAssetIDs.first,
                               targetSize: CGSize(width: 1200, height: 900))
                        .frame(maxWidth: .infinity).frame(height: heroHeight).clipped()
                }
            }
            LinearGradient(colors: [.clear, Color.bg.opacity(0.6), Color.bg],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
                .allowsHitTesting(false)
        }
        .frame(height: heroHeight)
        .overlay(alignment: .bottomTrailing) { multiPhotoHint }
    }

    /// 多图样式提示：右下角「张数」胶囊，暗示可左右滑动 / 自动播放中。
    @ViewBuilder private var multiPhotoHint: some View {
        if footprint.photoAssetIDs.count > 1 {
            HStack(spacing: 5) {
                Image(systemName: "rectangle.stack.fill").font(.system(size: 10, weight: .bold))
                Text("\(heroPage + 1)/\(footprint.photoAssetIDs.count)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 5).padding(.horizontal, 10)
            .background(.black.opacity(0.42), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .padding(.trailing, 16).padding(.bottom, 64)
        }
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.backward").font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.leading, 18).padding(.top, 58)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(footprint.flag).font(.system(size: 26))
                Text(footprint.title).font(Typo.serif(34)).foregroundStyle(Color.text)
            }
            Label {
                Text(coordinateLine).font(.system(size: 13)).foregroundStyle(Color.muted)
            } icon: {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.nPink)
            }
        }
    }

    private var statRow: some View {
        // 固定行高：长地区名（如阿语「الشرق الأوسط」）不再把格子撑高；
        // 「照片」「国家」窄一点，把宽度让给中间的「地区」。
        HStack(spacing: 10) {
            statCard("\(footprint.photoCount)", "照片", width: 72)
            statCard(footprint.region?.displayName.localized ?? "—", "地区")
            statCard(footprint.flag, "国家", width: 72)
        }
        .frame(height: 62)
    }

    private func statCard(_ value: String, _ label: String, width: CGFloat? = nil) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Typo.serif(20)).foregroundStyle(Color.text)
                .lineLimit(1).minimumScaleFactor(0.55)
            Text(label.localized).font(.system(size: 10.5)).foregroundStyle(Color.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(width: width, height: 62)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .panelCard(15)
    }

    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("同行人").font(.subheadline).foregroundStyle(Color.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(footprint.companions, id: \.self) { name in
                        Label(name, systemImage: "person.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.text)
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.glass, in: Capsule())
                            .overlay(Capsule().stroke(Color.nPurple.opacity(0.5), lineWidth: 1))
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.localized).font(.subheadline).foregroundStyle(Color.muted).frame(width: 64, alignment: .leading)
            Text(value).font(.subheadline).foregroundStyle(Color.text)
            Spacer()
        }
    }

    private var coordinateLine: String {
        var parts: [String] = []
        if !footprint.locationSubtitle.isEmpty { parts.append(footprint.locationSubtitle) }
        parts.append(String(format: "%.1f°, %.1f°", footprint.latitude, footprint.longitude))
        return parts.joined(separator: " · ")
    }
}
