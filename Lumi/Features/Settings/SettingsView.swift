import SwiftUI
import UIKit
import AuthenticationServices

/// 设置页。语言跟随系统——可在 iOS 系统设置里为 Lumi 单独选语言。
struct SettingsView: View {

    @ObservedObject private var store = PlusStore.shared
    @ObservedObject private var auth = AuthStore.shared
    @ObservedObject private var updater = AppUpdateCheck.shared
    @State private var showPaywall = false
    @State private var showWhatsNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("账户") { accountRow }
                section("Lumi Plus") { plusRow }
                section("个性化") { customizeEntry }
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
                section("关于") { aboutRows }
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
        .sheet(isPresented: $showWhatsNew) { WhatsNewSheet() }
        .task { await store.start() }
        .task { await updater.check(force: true) }
        .onAppear { auth.refreshCredentialState() }
    }

    // MARK: - 账户（Sign in with Apple · 纯客户端）

    @ViewBuilder private var accountRow: some View {
        if auth.isLoggedIn {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20)).foregroundStyle(Color.nCyan).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    (auth.displayName.isEmpty ? Text("已登录") : Text(verbatim: auth.displayName))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                    Text("通过 Apple 登录").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                Button("退出登录") { auth.signOut() }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nPink)
            }
            .padding(.vertical, 13).padding(.horizontal, 14)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("登录以同步与解锁会员权益（后续）").font(.system(size: 11))
                    .foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                SignInWithAppleButton(.signIn,
                    onRequest: { $0.requestedScopes = [.fullName] },   // 不取邮箱，零数据收集
                    onCompletion: { auth.handle($0) })
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 46)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 13).padding(.horizontal, 14)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
        }
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
                    Text("点这里发邮件给我们")
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

    // MARK: - 关于（版本 / 本次更新）

    private var aboutRows: some View {
        VStack(spacing: 0) {
            // 版本行：有新版本 → 可点去更新；否则显示已是最新版本
            Button {
                if let url = updater.available?.url { UIApplication.shared.open(url) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "app.badge").font(.system(size: 18))
                        .foregroundStyle(Color.nPink).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前版本 \(updater.currentVersion)")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.text)
                        Text(updater.available == nil ? "已是最新版本" : "有新版本可更新")
                            .font(.system(size: 11))
                            .foregroundStyle(updater.available == nil ? Color.muted : Color.nCyan)
                    }
                    Spacer()
                    if updater.available != nil {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.faint).flipsForRightToLeftLayoutDirection(true)
                    }
                }
                .padding(.vertical, 13).padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(updater.available == nil)

            Divider().overlay(Color.line).padding(.horizontal, 14)

            // 查看本次更新
            Button { showWhatsNew = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.system(size: 18))
                        .foregroundStyle(Color.nCyan).frame(width: 28)
                    Text("查看本次更新")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.text)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.faint).flipsForRightToLeftLayoutDirection(true)
                }
                .padding(.vertical, 13).padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 个性化入口（→ 展示台：小组件 / 明信片样式 / 邮票 / 护照风格）

    private var customizeEntry: some View {
        NavigationLink {
            CustomizeShowcaseView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill").font(.system(size: 18))
                    .foregroundStyle(Color.nPink).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("小组件 & 样式")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.text)
                    Text("浏览小组件、明信片样式、邮票与护照风格，点一下即应用")
                        .font(.system(size: 11)).foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
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

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.muted)
            content()
        }
    }
}
