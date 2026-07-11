import SwiftUI
import SwiftData

/// 「我」· 暗夜霓虹 v2。
/// 单用户本地档案：头像 + 等级 + 概览数字 + 升级进度 + 最近足迹。
/// v0 无账号 / 无社交（§8），不做好友动态流——只呈现真实本地数据。
struct ProfileView: View {

    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @AppStorage("lumi.profile.avatarID") private var avatarID: String = ""
    @ObservedObject private var post = LumiPost.shared
    @ObservedObject private var noticeCenter = NoticeCenter.shared
    /// 邮箱号分享卡渲染缓存。
    @State private var mailboxImage: Image?
    @State private var boxCopied = false

    private var stats: LumiStats { LumiStats(footprints: footprints) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileTop
                    levelBar
                    entryCard("book.closed.fill", "我的护照本",
                              "去过 \(stats.countries) 国 · 翻开看看出入境章", Color(hex: 0xC9A24B)) { PassportView() }
                    entryCard("rectangle.stack", "明信片墙", "收到的明信片都在这", Color.nPink) { PostcardWallView() }
                    entryCard("book.pages", "收集图鉴", "邮票 · 邮戳 · 节日章", Color.nPurple) { CodexView() }
                    entryCard("bag.fill", "商店", "邮票包 · 邮戳包 · 更多装扮", Color.nOrange) { StoreView() }
                    entryCard("heart.fill", "心愿单", "想去的地方", Color.nCyan) { WishlistView() }
                    entryCard("book.pages.fill", "交换日记", "两个人各写各的 · 交换才能拆开", Color(hex: 0xC9A24B)) { ExchangeDiaryListView() }
                    Color.clear.frame(height: 24)
                }
                .padding(.top, 16)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private var profileTop: some View {
        HStack(spacing: 14) {
            NavigationLink { ProfileEditView() } label: {
                ZStack {
                    if avatarID.isEmpty {
                        Circle().fill(LinearGradient.neon).frame(width: 60, height: 60)
                        Image(systemName: "sparkles").font(.system(size: 24)).foregroundStyle(.white)
                    } else {
                        AssetImage(assetID: avatarID, targetSize: CGSize(width: 200, height: 200))
                            .frame(width: 60, height: 60).clipShape(Circle())
                    }
                }
                .overlay(Circle().stroke(Color.nPurple, lineWidth: 2))
                .shadow(color: Color.nPurple.opacity(0.6), radius: 12)
            }
            VStack(alignment: .leading, spacing: 2) {
                (holderName.isEmpty ? Text("我的世界") : Text(verbatim: holderName))
                    .font(Typo.serif(22)).foregroundStyle(Color.text)
                Text("Lv.\(stats.level) 探索者").font(.system(size: 12)).foregroundStyle(Color.muted)
            }
            Spacer()
            if post.identity != nil { mailboxMenu }
            updatesButton
            NavigationLink { SettingsView() } label: { topIcon("gearshape") }
        }
        .padding(.horizontal, 26)
    }

    /// 动态入口（右上角小图标，未读数角标）。
    private var updatesButton: some View {
        NavigationLink { NoticeListView() } label: {
            topIcon("bell")
                .overlay(alignment: .topTrailing) {
                    if noticeCenter.unreadCount > 0 {
                        Text(verbatim: "\(min(noticeCenter.unreadCount, 99))")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 4.5).padding(.vertical, 2)
                            .background(Color.nPink, in: Capsule())
                            .overlay(Capsule().stroke(Color.bg, lineWidth: 1.5))
                            .offset(x: 4, y: -3)
                    }
                }
        }
        .accessibilityLabel(Text("动态"))
    }

    /// 快速分享我的邮箱号：复制号码 / 分享带品牌的图（与明信片墙分享同款）。
    private var mailboxMenu: some View {
        Menu {
            Button {
                if let box = post.identity?.boxID {
                    UIPasteboard.general.string = box
                    boxCopied = true
                    Haptics.selection()
                }
            } label: {
                Label(boxCopied ? "已复制" : "复制邮箱号", systemImage: boxCopied ? "checkmark" : "doc.on.doc")
            }
            if let img = mailboxImage {
                ShareLink(item: img, preview: SharePreview("Lumi", image: img)) {
                    Label("分享图片", systemImage: "square.and.arrow.up")
                }
            } else if let box = post.identity?.boxID {
                ShareLink(item: box) { Label("分享", systemImage: "square.and.arrow.up") }
            }
        } label: {
            topIcon("tray.and.arrow.up")   // 寄出/分享我的信箱（badge 版太像未读消息）
        }
        .task(id: post.identity?.boxID) {
            guard let box = post.identity?.boxID, mailboxImage == nil else { return }
            mailboxImage = ShareRender.image(MailboxShareCard(boxID: box))
        }
        .accessibilityLabel(Text("分享邮箱号"))
    }

    private func entryCard<D: View>(_ icon: String, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey,
                                    _ tint: Color, badge: Int = 0,
                                    @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(tint).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                if badge > 0 {
                    Text(verbatim: "\(badge)")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.nPink, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.faint)
            }
            .padding(16)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
        }
        .padding(.horizontal, 26).padding(.top, 12)
    }

    private func topIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.text)
            .frame(width: 38, height: 38)
            .background(Color.panel, in: Circle())
            .overlay(Circle().stroke(Color.line, lineWidth: 1))
    }

    private var levelBar: some View {
        VStack(spacing: 7) {
            HStack {
                Text("距离 Lv.\(stats.level + 1) 还差 \(stats.toNextLevel) 国")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
                Spacer()
                Text("\(Int(stats.levelProgress * 100))%")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.text)
            }
            NeonBar(fraction: stats.levelProgress, height: 8)
        }
        .padding(.horizontal, 26).padding(.top, 16)
    }

    @ViewBuilder
    private var recentSection: some View {
        Text("最近点亮 Recent").font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.muted).padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 8)
        if footprints.isEmpty {
            Text("还没有足迹 · 回地图点亮第一个地方")
                .font(.system(size: 12)).foregroundStyle(Color.faint)
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
        } else {
            ForEach(footprints.prefix(5)) { fp in
                HStack(spacing: 11) {
                    Text(fp.flag).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fp.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                        Text(fp.countryName ?? "未知地区").font(.system(size: 10.5)).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Text(fp.visitedAt.formatted(.dateTime.month().day()))
                        .font(.system(size: 10)).foregroundStyle(Color.faint)
                }
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(Color.glass, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.line, lineWidth: 1))
                .padding(.horizontal, 22).padding(.bottom, 10)
            }
        }
    }
}
