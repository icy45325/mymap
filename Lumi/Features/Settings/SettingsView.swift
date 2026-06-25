import SwiftUI
import UIKit

/// 设置页。语言跟随系统——可在 iOS 系统设置里为 Lumi 单独选语言。
struct SettingsView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("语言 Language") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("语言跟随系统").foregroundStyle(Color.text)
                                Text("在「系统设置 › Lumi」里可单独为本应用选择语言")
                                    .font(.system(size: 11)).foregroundStyle(Color.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app").foregroundStyle(Color.nPink)
                        }
                        .padding(.vertical, 13).padding(.horizontal, 14)
                    }
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
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

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.muted)
            content()
        }
    }
}
