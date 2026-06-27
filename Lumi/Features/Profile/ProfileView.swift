import SwiftUI
import SwiftData

/// 「我」· 暗夜霓虹 v2。
/// 单用户本地档案：头像 + 等级 + 概览数字 + 升级进度 + 最近足迹。
/// v0 无账号 / 无社交（§8），不做好友动态流——只呈现真实本地数据。
struct ProfileView: View {

    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    @AppStorage("lumi.profile.name") private var holderName: String = "旅行者"
    @AppStorage("lumi.profile.avatarID") private var avatarID: String = ""

    private var stats: LumiStats { LumiStats(footprints: footprints) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileTop
                    statsRow
                    levelBar
                    entryCard("book.closed.fill", "我的护照本",
                              "去过 \(stats.countries) 国 · 翻开看看出入境章", Color(hex: 0xC9A24B)) { PassportView() }
                    entryCard("rectangle.stack", "明信片墙", "收到的明信片都在这", Color.nPink) { PostcardWallView() }
                    entryCard("heart.fill", "心愿单", "想去的地方", Color.nCyan) { WishlistView() }
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
                Text(holderName.isEmpty ? "我的世界" : holderName).font(Typo.serif(22)).foregroundStyle(Color.text)
                Text("Lv.\(stats.level) 探索者").font(.system(size: 12)).foregroundStyle(Color.muted)
            }
            Spacer()
            NavigationLink { SettingsView() } label: { topIcon("gearshape") }
        }
        .padding(.horizontal, 26)
    }

    private func entryCard<D: View>(_ icon: String, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey,
                                    _ tint: Color, @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(tint).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
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

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("\(stats.countries)", "国家")
            stat("\(stats.cities)", "城市")
            stat("\(stats.badgeBoard.unlockedCount)", "勋章")
        }
        .padding(.horizontal, 26).padding(.top, 16)
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(Typo.serif(21)).foregroundStyle(Color.text)
            Text(l.localized).font(.system(size: 10)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).panelCard(15)
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
