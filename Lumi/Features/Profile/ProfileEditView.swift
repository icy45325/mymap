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
    @State private var showNationalityPicker = false

    /// 全量 ISO 3166-1 国家/地区码（按本地化名排序），不再用手挑短名单。
    static let allNationalities: [String] = {
        let codes = Locale.Region.isoRegions.map(\.identifier)
            .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) && $0 != "ZZ" }
        return Array(Set(codes)).sorted {
            (CountryInfo.localizedName(for: $0) ?? $0)
                .localizedCaseInsensitiveCompare(CountryInfo.localizedName(for: $1) ?? $1) == .orderedAscending
        }
    }()

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
                        Button { showNationalityPicker = true } label: {
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
            .sheet(isPresented: $showNationalityPicker) {
                NationalityPickerSheet(selected: $nationality)
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

/// 国籍选择：全量 ISO 国家/地区，支持按名称 / 代码搜索。
private struct NationalityPickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return ProfileEditView.allNationalities }
        return ProfileEditView.allNationalities.filter {
            ($0.localizedCaseInsensitiveContains(q)) ||
            (CountryInfo.localizedName(for: $0)?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered, id: \.self) { c in
                        Button {
                            selected = c; Haptics.selection(); dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Text(flagEmoji(c)).font(.system(size: 20))
                                Text(CountryInfo.localizedName(for: c) ?? c)
                                    .font(.system(size: 15)).foregroundStyle(Color.text)
                                Spacer()
                                if c == selected {
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.nPink)
                                }
                            }
                            .padding(.vertical, 11).padding(.horizontal, 18)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.line.opacity(0.5)).padding(.leading, 48)
                    }
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("选择国籍")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索国家 / 地区")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
