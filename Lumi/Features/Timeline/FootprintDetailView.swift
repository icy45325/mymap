import SwiftUI

/// 明信片卡详情（§4.3）· 暗夜霓虹 v2。支持编辑（地点名 / 日期 / 心情 / 同行人）。
struct FootprintDetailView: View {

    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showPostcard = false
    @State private var showDiary = false
    @State private var heroPage = 0
    @State private var flipGen = 0      // 自动翻页「代」标记：只允许最新一代写入，杜绝双计时器跳页
    @State private var delivery: (sent: Int, delivered: Int)?   // v1.1 直寄回执（无记录 = nil 不渲染）

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
                    if let d = delivery, d.sent > 0 { deliveryRow(d) }
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
        .sheet(isPresented: $showDiary) {
            NewDiarySheet(prefillTitle: diaryTitle,
                          suggestedNames: footprint.companions,
                          footprintID: footprint.id)
        }
        .task(id: showPostcard) {   // 打开时查一次；直寄弹窗关回来再查（拿到刚寄的那封）
            guard LumiPostConfig.isEnabled, !showPostcard else { return }
            let d = await LumiPost.shared.deliveredCount(for: footprint.id.uuidString)
            if d.sent > 0 { delivery = d }
        }
    }

    /// v1.1 直寄回执：这张卡直寄过 → 全部送达打 ✓，否则显示等待中。
    private func deliveryRow(_ d: (sent: Int, delivered: Int)) -> some View {
        HStack(spacing: 7) {
            Image(systemName: d.delivered >= d.sent ? "checkmark.seal.fill" : "paperplane.circle")
                .font(.system(size: 13))
                .foregroundStyle(d.delivered >= d.sent ? Color.nCyan : Color.muted)
            if d.delivered >= d.sent {
                Text("已送达 ✓").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.nCyan)
            } else {
                Text("已寄出 · 等待送达").font(.system(size: 12)).foregroundStyle(Color.muted)
            }
            if d.sent > 1 {
                Text(verbatim: "\(d.delivered)/\(d.sent)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.muted)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Color.panel, in: Capsule())
        .overlay(Capsule().stroke(Color.line, lineWidth: 1))
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
                    // 单一生命周期内的自动翻页：每 3.5s 只前进一页（睡眠在前进之后，
                    // 不会出现多个定时器叠加导致「跳页 / 停在两页之间」）。
                    .task(id: footprint.photoAssetIDs.count) {
                        let count = footprint.photoAssetIDs.count
                        guard count > 1 else { return }
                        flipGen += 1
                        let myGen = flipGen          // 本代 token；若有第二个 task 启动会把 flipGen 推高，旧代自动退出
                        var page = heroPage          // 本地推进，绝不回读 @State，避免读到旧值后 +1 造成 +2 跳页
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(3.5))
                            if Task.isCancelled || myGen != flipGen { break }
                            page = (page + 1) % count
                            withAnimation(.easeInOut(duration: 0.55)) { heroPage = page }
                        }
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
                        HStack(spacing: 6) {
                            PersonAvatar.named(name, size: 20)   // 往来的人命中真头像，手输名字首字母
                            Text(verbatim: name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.text)
                        }
                        .padding(.vertical, 5).padding(.horizontal, 10)
                        .background(Color.glass, in: Capsule())
                        .overlay(Capsule().stroke(Color.nPurple.opacity(0.5), lineWidth: 1))
                    }
                }
            }
            // 一个足迹=一段旅程：旅伴就在这里，直接开一本交换日记
            Button { showDiary = true } label: {
                Label("与旅伴交换日记", systemImage: "book.pages")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.nPink)
                    .padding(.vertical, 8).padding(.horizontal, 14)
                    .background(Color.panel, in: Capsule())
                    .overlay(Capsule().stroke(Color.nPink.opacity(0.4), lineWidth: 1))
            }
            .padding(.top, 2)
        }
    }

    /// 交换日记预填标题：「地点 年份」。
    private var diaryTitle: String {
        let year = Calendar.current.component(.year, from: footprint.visitedAt)
        return "\(footprint.title) \(String(year))"
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
