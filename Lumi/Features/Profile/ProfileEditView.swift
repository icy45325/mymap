import SwiftUI
import PhotosUI

/// 个人资料：上传头像 + 昵称 + 国籍。驱动护照持有人页与封面颜色。
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.profile.name") private var name: String = ""
    @AppStorage("lumi.profile.nationality") private var nationality: String = ""
    @AppStorage("lumi.profile.avatarID") private var avatarID: String = ""
    @AppStorage("lumi.passport.style") private var passportStyle: String = PassportStyle.classic.rawValue
    @State private var pickerItem: PhotosPickerItem?

    private let nationalities = ["CN", "HK", "TW", "JP", "KR", "SG", "MY", "TH", "VN", "ID", "IN",
                                 "AE", "SA", "QA", "TR", "RU", "GB", "FR", "DE", "IT", "ES", "NL",
                                 "CH", "GR", "PT", "IE", "US", "CA", "MX", "BR", "AU", "NZ", "ZA",
                                 "EG", "MA", "NG"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if avatarID.isEmpty {
                                    ZStack { Circle().fill(Color.panel)
                                        Image(systemName: "person.fill").font(.system(size: 40)).foregroundStyle(Color.muted) }
                                } else {
                                    AssetImage(assetID: avatarID, targetSize: CGSize(width: 300, height: 300))
                                }
                            }
                            .frame(width: 100, height: 100).clipShape(Circle())
                            .overlay(Circle().stroke(Color.nPurple, lineWidth: 2))
                            Image(systemName: "camera.fill").font(.system(size: 12)).foregroundStyle(.white)
                                .padding(7).background(Color.nPink, in: Circle())
                        }
                    }
                    .padding(.top, 10)

                    section("昵称") {
                        TextField("你的昵称", text: $name)
                            .foregroundStyle(Color.text).padding(12)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                    }

                    section("国籍") {
                        Menu {
                            ForEach(nationalities, id: \.self) { c in
                                Button { nationality = c } label: {
                                    Text("\(flagEmoji(c))  \(CountryInfo.localizedName(for: c) ?? c)")
                                }
                            }
                        } label: {
                            HStack {
                                Text(nationality.isEmpty ? "选择国籍"
                                     : "\(flagEmoji(nationality))  \(CountryInfo.localizedName(for: nationality) ?? nationality)")
                                    .foregroundStyle(nationality.isEmpty ? Color.muted : Color.text)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Color.muted)
                            }
                            .padding(12)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                        }
                    }

                    section("护照风格") {
                        HStack(spacing: 8) {
                            ForEach(PassportStyle.allCases) { s in
                                let active = passportStyle == s.rawValue
                                Button { passportStyle = s.rawValue } label: {
                                    Text(s.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                                        .background(active ? AnyShapeStyle(LinearGradient.neonH) : AnyShapeStyle(Color.panel),
                                                    in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .stroke(active ? Color.clear : Color.line, lineWidth: 1))
                                        .foregroundStyle(active ? .white : Color.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.foregroundStyle(Color.nPink)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: pickerItem) { _, item in
                if let id = item?.itemIdentifier { avatarID = id }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
            content()
        }
    }
}
