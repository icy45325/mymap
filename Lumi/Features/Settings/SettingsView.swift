import SwiftUI

/// 应用语言选择。`appLanguage` 持久化，由根视图（LumiApp）读取并套用 locale + 布局方向。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zh, en, ar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .zh:     return "中文"
        case .en:     return "English"
        case .ar:     return "العربية"
        }
    }

    /// 对应 locale 标识；system 用系统默认。
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .zh:     return "zh-Hans"
        case .en:     return "en"
        case .ar:     return "ar"
        }
    }

    /// 阿语右起，其余左起。
    var layoutDirection: LayoutDirection {
        self == .ar ? .rightToLeft : .leftToRight
    }
}

extension View {
    /// 套用所选语言：覆盖 locale + 布局方向（阿语→RTL）；system 则不覆盖、跟随系统。
    @ViewBuilder
    func applyLanguage(_ lang: AppLanguage) -> some View {
        if let id = lang.localeIdentifier {
            environment(\.locale, Locale(identifier: id))
                .environment(\.layoutDirection, lang.layoutDirection)
        } else {
            self
        }
    }
}

struct SettingsView: View {

    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.system.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(get: { AppLanguage(rawValue: appLanguage) ?? .system },
                set: { appLanguage = $0.rawValue })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("语言 Language") {
                    VStack(spacing: 0) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button { selection.wrappedValue = lang } label: {
                                HStack {
                                    Text(lang.label).foregroundStyle(Color.text)
                                    Spacer()
                                    if selection.wrappedValue == lang {
                                        Image(systemName: "checkmark").foregroundStyle(Color.nPink)
                                    }
                                }
                                .padding(.vertical, 13).padding(.horizontal, 14)
                            }
                            if lang != AppLanguage.allCases.last {
                                Divider().overlay(Color.lineSoft).padding(.leading, 14)
                            }
                        }
                    }
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))

                    Text("切换阿拉伯语会将界面切为从右到左布局。界面文案的完整本地化仍在逐步补全中。")
                        .font(.system(size: 11)).foregroundStyle(Color.faint)
                        .padding(.top, 8).padding(.horizontal, 2)
                }
            }
            .padding(20)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.muted)
            content()
        }
    }
}
