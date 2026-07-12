import SwiftUI

/// 通用人像：有头像图（base64 缩略图，随明信片传来）就显示真图；
/// 没有（如手输名字的旅伴）则显示「首字母 + 霓虹渐变」默认头像。
/// 旅伴 / 往来的人 / 交换日记伙伴共用；只做按名字的本地弱关联，不依赖好友关系。
struct PersonAvatar: View {
    let name: String
    var avatarB64: String? = nil
    var size: CGFloat = 24

    var body: some View {
        if let b64 = avatarB64, let data = Data(base64Encoded: b64), let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(Circle())
                .overlay(Circle().stroke(Color.line, lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(LinearGradient.neon).frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.line, lineWidth: 1))
                Text(String(name.prefix(1))).font(Typo.serif(size * 0.4)).foregroundStyle(.white)
            }
        }
    }
}

extension PersonAvatar {
    /// 按名字弱关联「往来的人」：命中带出真头像，未命中默认首字母头像。
    @MainActor
    static func named(_ name: String, size: CGFloat) -> PersonAvatar {
        PersonAvatar(name: name, avatarB64: PostcardContacts.shared.contact(named: name)?.avatarB64, size: size)
    }
}

/// 头像堆叠：≤3 个重叠排列，多出的显示 +N（时间线旅伴 / 日记书架共用）。
struct PartnerAvatarStack: View {
    let names: [String]
    var size: CGFloat = 22

    var body: some View {
        let shown = Array(names.prefix(3))
        HStack(spacing: -size * 0.28) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, name in
                PersonAvatar.named(name, size: size)
                    .overlay(Circle().stroke(Color.bg, lineWidth: 1.5))
            }
            if names.count > 3 {
                ZStack {
                    Circle().fill(Color.panel).frame(width: size, height: size)
                        .overlay(Circle().stroke(Color.line, lineWidth: 1))
                    Text(verbatim: "+\(names.count - 3)")
                        .font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(Color.muted)
                }
            }
        }
    }
}
