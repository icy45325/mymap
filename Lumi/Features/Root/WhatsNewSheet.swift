import SwiftUI

extension Bundle {
    /// 本机展示版本号（`CFBundleShortVersionString`）。
    var shortVersion: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0" }
}

/// 「本次更新」内容——**每次发版在此维护当前版本亮点**（无后端「推送新功能」）。
/// 发版时：bump Xcode `MARKETING_VERSION` 后，把 `version` 同步成同一号、改 `highlights`。
enum WhatsNew {
    /// 与 `MARKETING_VERSION` 保持一致；用于判断「升级后首开」。
    static let version = "0.2"

    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let desc: LocalizedStringKey
    }

    /// 本版本功能亮点。
    static let highlights: [Item] = [
        Item(icon: "map.fill", title: "心愿单上地图",
             desc: "全屏地图用霓虹青标出想去的地方，和去过的粉色一眼区分"),
        Item(icon: "hand.tap.fill", title: "点国家更顺手",
             desc: "点一个国家，弹出一个面板：点亮 / 心愿 / 看去过的城市 / 推荐城市一键操作"),
        Item(icon: "square.and.arrow.up.fill", title: "成就报告可分享",
             desc: "把你的世界点亮战绩导成一张紫色霓虹海报，发出去"),
        Item(icon: "apple.logo", title: "用 Apple 登录",
             desc: "在设置里用 Apple 一键登录，为后续会员权益打底"),
        Item(icon: "sparkles", title: "更跟手的反馈",
             desc: "点亮、切换、解锁徽章都加了触觉反馈"),
    ]
}

/// 「本次更新」弹窗：升级后首次打开弹一次，或在设置页「查看本次更新」手动打开。
struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    VStack(spacing: 12) {
                        ForEach(WhatsNew.highlights) { row($0) }
                    }
                    Button { dismiss() } label: {
                        Text("知道了").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(LinearGradient.neonH, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✦").font(.system(size: 36)).foregroundStyle(LinearGradient.neonH)
            Text("本次更新 ✦").font(Typo.serif(28)).foregroundStyle(Color.text)
            Text("点亮你的旅行足迹 · Lumi")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
        }
        .padding(.top, 4)
    }

    private func row(_ item: WhatsNew.Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon).font(.system(size: 17)).foregroundStyle(Color.nPink)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
                Text(item.desc).font(.system(size: 11)).foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }
}
