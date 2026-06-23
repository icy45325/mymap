import SwiftUI
import SwiftData

/// 「我」· 暗夜霓虹 v2。
/// 单用户本地档案：头像 + 等级 + 概览数字 + 升级进度 + 最近足迹。
/// v0 无账号 / 无社交（§8），不做好友动态流——只呈现真实本地数据。
struct ProfileView: View {

    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    private var stats: LumiStats { LumiStats(footprints: footprints) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileTop
                    statsRow
                    levelBar
                    recentSection
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
            ZStack {
                Circle().fill(LinearGradient.neon).frame(width: 60, height: 60)
                Image(systemName: "sparkles").font(.system(size: 24)).foregroundStyle(.white)
            }
            .overlay(Circle().stroke(Color.nPurple, lineWidth: 2))
            .shadow(color: Color.nPurple.opacity(0.6), radius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text("我的世界").font(Typo.serif(22)).foregroundStyle(Color.text)
                Text("Lv.\(stats.level) 探索者").font(.system(size: 12)).foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 26)
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
            Text(l).font(.system(size: 10)).foregroundStyle(Color.muted)
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
