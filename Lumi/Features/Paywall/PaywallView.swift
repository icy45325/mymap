import SwiftUI
import StoreKit

/// Lumi Plus 升级页（轻 paywall）：价值点 + 计划选择 + 购买 / 恢复 + 条款。
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PlusStore.shared
    @State private var selected: Product?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    valueProps
                    plans
                    cta
                    legal
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("Lumi Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("恢复购买") { Task { await store.restore() } }
                        .font(.system(size: 13)).foregroundStyle(Color.nCyan)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .task { await store.start(); syncSelection() }
        .onChange(of: store.products.count) { _, _ in syncSelection() }
        .onChange(of: store.isPlus) { _, isPlus in if isPlus { showSuccess = true } }
        .alert("已解锁 Lumi Plus ✦", isPresented: $showSuccess) {
            Button("好") { dismiss() }
        } message: { Text("感谢支持——所有 Plus 权益已为你打开。") }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Text("✦").font(.system(size: 40))
                .foregroundStyle(LinearGradient.neonH)
            Text("Lumi Plus").font(Typo.serif(30)).foregroundStyle(Color.text)
            Text("解锁更精致的明信片与更多记忆增益")
                .font(.system(size: 13)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - 价值点

    private var valueProps: some View {
        VStack(spacing: 12) {
            prop("infinity", "后续所有功能迭代", "一次解锁，未来新增 Plus 功能全部包含", available: true)
            prop("sparkles", "明信片无水印 · 高清导出", "去掉 Lumi 水印，3 倍分辨率导出", available: true)
            prop("photo.stack", "典藏国家邮票", "中国/美国/日本/阿联酋 14 枚典藏票，寄该地明信片专属可用", available: true)
            prop("paintpalette.fill", "主题色 · 专属图标 · 小组件", "极光/暖阳整套主题（高亮+地图+图标），主屏小组件", available: true)
            prop("icloud", "云同步 · 多设备 · 跨平台", "换机不丢，iOS / Android 共享权益", available: false)
            prop("chart.bar.xaxis", "进阶统计 · 年度回顾", "更深的足迹洞察与年度叙事", available: false)
        }
    }

    private func prop(_ icon: String, _ title: LocalizedStringKey, _ desc: LocalizedStringKey, available: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Color.nPink)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
                Text(desc).font(.system(size: 11)).foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(available ? "现已可用" : "即将推出")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(available ? Color.nCyan : Color.faint)
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background((available ? Color.nCyan : Color.faint).opacity(0.14), in: Capsule())
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 计划

    private var plans: some View {
        Group {
            if store.products.isEmpty {
                ProgressView().tint(Color.nPink).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.products, id: \.id) { product in
                        planCard(product)
                    }
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let kind = PlusProduct(rawValue: product.id)
        let isSel = selected?.id == product.id
        return Button { selected = product } label: {
            HStack(spacing: 12) {
                Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundStyle(isSel ? Color.nPink : Color.line)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(kind?.title ?? product.displayName)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                        Text("早鸟会员")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(.vertical, 3).padding(.horizontal, 7)
                            .background(LinearGradient.neonH, in: Capsule())
                    }
                    Text(priceSubtitle(product, kind: kind))
                        .font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                Text(product.displayPrice).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.text)
            }
            .padding(14)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSel ? Color.nPink.opacity(0.6) : Color.line, lineWidth: isSel ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var cta: some View {
        Button {
            guard let product = selected else { return }
            Task { _ = await store.purchase(product) }
        } label: {
            Group {
                if store.purchasing { ProgressView().tint(.white) }
                else { Text(ctaTitle).font(.headline) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(LinearGradient.neonH, in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: Color.nPurple.opacity(0.5), radius: 12)
        }
        .disabled(selected == nil || store.purchasing)
        .opacity(selected == nil ? 0.5 : 1)
    }

    private var ctaTitle: LocalizedStringKey { "成为终身会员" }

    // MARK: - 条款

    private var legal: some View {
        VStack(spacing: 8) {
            Text("一次性买断，永久解锁全部功能与后续所有迭代。付款将在确认购买时记入你的 Apple ID，不会自动续费。")
                .font(.system(size: 10)).foregroundStyle(Color.faint)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("隐私政策", destination: URL(string: "https://icy45325.github.io/mymap/legal/privacy.html")!)
                Link("使用条款", destination: URL(string: "https://icy45325.github.io/mymap/legal/terms.html")!)
            }
            .font(.system(size: 11)).foregroundStyle(Color.nCyan)
        }
        .padding(.top, 4)
    }

    // MARK: - 派生

    private func syncSelection() {
        guard selected == nil else { return }
        selected = store.products.first
    }

    private func priceSubtitle(_ product: Product, kind: PlusProduct?) -> LocalizedStringKey {
        "一次买断 · 永久解锁 · 含后续所有迭代"
    }
}
