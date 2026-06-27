import SwiftUI
import UIKit

/// 设置页。语言跟随系统——可在 iOS 系统设置里为 Lumi 单独选语言。
struct SettingsView: View {

    @ObservedObject private var store = PlusStore.shared
    @AppStorage("lumi.passport.style") private var passportStyle: String = PassportStyle.classic.rawValue
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Lumi Plus") { plusRow }
                section("护照风格") { passportStyleRow }
                section("小组件 Widgets") {
                    VStack(alignment: .leading, spacing: 12) {
                        widgetPreviewStrip
                        Divider().overlay(Color.line)
                        widgetRow("rectangle.3.group", "点亮计数", "主屏 / 锁屏显示已点亮国家数与全球占比")
                        Divider().overlay(Color.line)
                        widgetRow("calendar", "去年今日", "回看往年此刻去过的地方")
                        Divider().overlay(Color.line)
                        widgetRow("flag.2.crossed", "去过的国旗", "展示去过国家的国旗集合（最多 5 个）")
                        Divider().overlay(Color.line)
                        Text("添加方式：长按桌面空白处 → 左上角「+」→ 搜索 “Lumi” → 选择小组件。小组件文案跟随系统语言。")
                            .font(.system(size: 11)).foregroundStyle(Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                }
                section("语言 Language") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("语言跟随系统").foregroundStyle(Color.text)
                                Text("中文显示中文、阿拉伯语显示阿语，其余默认英文；如需单独指定，可在「系统设置 › Lumi」里调整。")
                                    .font(.system(size: 11)).foregroundStyle(Color.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .flipsForRightToLeftLayoutDirection(true).foregroundStyle(Color.nPink)
                        }
                        .padding(.vertical, 13).padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                }
                section("反馈与建议") { feedbackRow }
            }
            .padding(20)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { await store.start() }
    }

    // MARK: - Lumi Plus 入口

    private var plusRow: some View {
        Button { if !store.isPlus { showPaywall = true } } label: {
            HStack(spacing: 12) {
                Image(systemName: store.isPlus ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 20)).foregroundStyle(store.isPlus ? Color.nCyan : Color.nPink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isPlus ? "Lumi Plus 已解锁" : "升级 Lumi Plus")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                    Text(store.isPlus ? "感谢支持——全部权益已开启 ✦" : "明信片去水印高清导出，更多增益陆续解锁")
                        .font(.system(size: 11)).foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !store.isPlus {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.faint).flipsForRightToLeftLayoutDirection(true)
                }
            }
            .padding(.vertical, 13).padding(.horizontal, 14)
            .contentShape(Rectangle())   // 整行可点（含 Spacer 空白区），避免点空白没反应
        }
        .buttonStyle(.plain)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(store.isPlus ? Color.nCyan.opacity(0.4) : Color.line, lineWidth: 1))
    }

    // MARK: - 反馈与建议（邮件）

    private var feedbackRow: some View {
        Button {
            let subject = String(localized: "Lumi 反馈")
            let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
            if let url = URL(string: "mailto:icy45325@hotmail.com?subject=\(encoded)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18)).foregroundStyle(Color.nCyan).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("有想法或遇到问题？写信告诉我们")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("icy45325@hotmail.com")
                        .font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.faint).flipsForRightToLeftLayoutDirection(true)
            }
            .padding(.vertical, 13).padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 护照风格切换

    private var passportStyleRow: some View {
        HStack(spacing: 8) {
            ForEach(PassportStyle.allCases) { s in
                let active = passportStyle == s.rawValue
                Button { passportStyle = s.rawValue } label: {
                    Text(s.label)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(active ? AnyShapeStyle(LinearGradient.neonH) : AnyShapeStyle(Color.panel),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Color.clear : Color.line, lineWidth: 1))
                        .foregroundStyle(active ? .white : Color.muted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 小组件样式预览（App 内近似 mock，非真实小组件渲染）

    private var widgetPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statsPreview
                flagsPreview
                onThisDayPreview
            }
            .padding(.vertical, 2)
        }
    }

    private var previewBG: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x12101F), Color(hex: 0x0A0A16)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func previewCard<C: View>(_ section: LocalizedStringKey, width: CGFloat = 150,
                                      @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LUMI · ").font(.system(size: 8, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.muted)
            + Text(section).font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(Color.muted)
            content()
        }
        .frame(width: width, height: 96, alignment: .topLeading)
        .padding(11)
        .background(previewBG, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    private var statsPreview: some View {
        previewCard("点亮战绩") {
            Spacer(minLength: 0)
            Text("12").font(Typo.serif(34)).foregroundStyle(Color.nOrange)
            Text("个国家 · 全球 5%").font(.system(size: 9)).foregroundStyle(Color.text)
        }
    }
    private var flagsPreview: some View {
        previewCard("去过的国旗") {
            Spacer(minLength: 0)
            Text(["AE","CN","JP","FR","GB"].map(flagEmoji).joined())
                .font(.system(size: 22))
            Text("已点亮 12 国").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.text)
        }
    }
    private var onThisDayPreview: some View {
        previewCard("去年今日") {
            Spacer(minLength: 0)
            Text("✈️").font(.system(size: 26))
            Text("去年此刻你在 东京 ✦").font(.system(size: 9)).foregroundStyle(Color.text).lineLimit(2)
        }
    }

    private func widgetRow(_ icon: String, _ name: LocalizedStringKey, _ desc: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Color.nPink)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.text)
                Text(desc).font(.system(size: 11)).foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.muted)
            content()
        }
    }
}
