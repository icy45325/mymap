import Foundation

/// 一位「往来的人」：收 / 发明信片攒下的昵称（纯本地，无账号）。
struct PostcardContact: Codable, Identifiable, Equatable {
    var name: String
    var lastAt: Date
    var sentCount: Int = 0
    var receivedCount: Int = 0
    var boxID: String? = nil        // 对方的 Lumi 邮箱号（v1.1 直寄；旧数据无此字段自然为 nil）
    var avatarB64: String? = nil    // 对方头像缩略图（随收到的明信片传来）
    var countryCode: String? = nil  // 对方国籍码（ISO2）
    var id: String { name }
}

/// 明信片联系人 / 往来（本地 social-lite）：从收 / 发明信片攒「往来的人」名单，
/// 寄信时可直接选，不用每次手输。**纯本地**（UserDefaults JSON），为日后接账号先攒数据。
@MainActor
final class PostcardContacts: ObservableObject {
    static let shared = PostcardContacts()

    @Published private(set) var contacts: [PostcardContact] = []
    private let key = "lumi.postcardContacts.v1"

    private init() { load() }

    /// 近期往来（按最近一次时间倒序）。
    var recent: [PostcardContact] { contacts.sorted { $0.lastAt > $1.lastAt } }

    /// 记一笔往来：寄出（sent）或收到（!sent）。同名（忽略大小写）合并计数；
    /// 带 `boxID`（直寄邮箱号）/ `avatarB64` / `countryCode`（随收到的卡传来）则记住 / 更新。
    func record(_ rawName: String?, boxID: String? = nil, avatarB64: String? = nil,
                countryCode: String? = nil, sent: Bool, at date: Date = Date()) {
        guard let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
        // 自己不进「往来的人」：自寄自收（测试/自嗨）会让收发两侧都把「自己」记成联系人。
        // 按本机邮箱号（最可靠）与本机资料名（兜底）双重识别，集中在这里过滤，所有调用点一并生效。
        if let boxID, boxID == LumiPost.shared.identity?.boxID { return }
        let myName = (UserDefaults.standard.string(forKey: "lumi.profile.name") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !myName.isEmpty, name.caseInsensitiveCompare(myName) == .orderedSame { return }
        if let i = contacts.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            contacts[i].lastAt = date
            if sent { contacts[i].sentCount += 1 } else { contacts[i].receivedCount += 1 }
            if let boxID { contacts[i].boxID = boxID }
            if let avatarB64 { contacts[i].avatarB64 = avatarB64 }
            if let countryCode { contacts[i].countryCode = countryCode }
        } else {
            contacts.append(PostcardContact(name: name, lastAt: date,
                                            sentCount: sent ? 1 : 0, receivedCount: sent ? 0 : 1,
                                            boxID: boxID, avatarB64: avatarB64, countryCode: countryCode))
        }
        save()
    }

    func remove(_ contact: PostcardContact) {
        contacts.removeAll { $0.id == contact.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PostcardContact].self, from: data) else { return }
        contacts = decoded
    }
    private func save() {
        if let data = try? JSONEncoder().encode(contacts) { UserDefaults.standard.set(data, forKey: key) }
    }
}
