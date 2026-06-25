import SwiftUI

/// 明信片卡详情（§4.3）· 暗夜霓虹 v2。支持编辑（地点名 / 日期 / 心情 / 同行人）。
struct FootprintDetailView: View {

    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showPostcard = false

    private static let dateFormat: Date.FormatStyle = .dateTime.year().month(.wide).day()

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
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
        .padding(.trailing, 18).padding(.top, 50)
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            Group {
                if footprint.photoAssetIDs.count > 1 {
                    // 多图：左右滑动切换 + 页码圆点（§验收 #4）
                    TabView {
                        ForEach(footprint.photoAssetIDs, id: \.self) { id in
                            AssetImage(assetID: id, targetSize: CGSize(width: 1200, height: 900))
                                .frame(maxWidth: .infinity).frame(height: 260).clipped()
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                } else {
                    AssetImage(assetID: footprint.photoAssetIDs.first,
                               targetSize: CGSize(width: 1200, height: 900))
                        .frame(maxWidth: .infinity).frame(height: 260).clipped()
                }
            }
            LinearGradient(colors: [.clear, Color.bg.opacity(0.6), Color.bg],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
                .allowsHitTesting(false)
        }
        .frame(height: 260)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.backward").font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.leading, 18).padding(.top, 50)
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
        HStack(spacing: 10) {
            statCard("\(footprint.photoCount)", "照片")
            statCard(footprint.region?.displayName.localized ?? "—", "地区")
            statCard(footprint.flag, "国家")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Typo.serif(20)).foregroundStyle(Color.text)
            Text(label.localized).font(.system(size: 10.5)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 13)
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
