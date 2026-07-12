import Foundation

/// 一条动态：收到新明信片 / 交换日记更新（伙伴的日记寄到）。
struct Notice: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case postcard, diary }

    var id = UUID()
    var kindRaw: String
    var title: String
    var subtitle: String
    var date: Date = .now
    /// 跳转目标：postcard = Footprint.id / diary = DiaryBook.id（uuidString）。
    var targetID: String
    var read: Bool = false

    var kind: Kind { Kind(rawValue: kindRaw) ?? .postcard }
}

/// 动态中心（纯本地，UserDefaults JSON）：未读数供 Me tab 角标与 Me 页「动态」行展示，
/// 列表见 `NoticeListView`。只记「收到的东西」，不做推送。
@MainActor
final class NoticeCenter: ObservableObject {
    static let shared = NoticeCenter()

    @Published private(set) var notices: [Notice] = []
    private let key = "lumi.notices.v1"
    private let cap = 100                      // 只留最近 100 条

    private init() { load() }

    var unreadCount: Int { notices.filter { !$0.read }.count }

    func add(_ kind: Notice.Kind, title: String, subtitle: String, targetID: String) {
        notices.insert(Notice(kindRaw: kind.rawValue, title: title, subtitle: subtitle, targetID: targetID),
                       at: 0)
        if notices.count > cap { notices = Array(notices.prefix(cap)) }
        save()
    }

    func markRead(_ id: UUID) {
        guard let i = notices.firstIndex(where: { $0.id == id }), !notices[i].read else { return }
        notices[i].read = true
        save()
    }

    func markAllRead() {
        guard unreadCount > 0 else { return }
        for i in notices.indices { notices[i].read = true }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Notice].self, from: data) else { return }
        notices = decoded
    }
    private func save() {
        if let data = try? JSONEncoder().encode(notices) { UserDefaults.standard.set(data, forKey: key) }
    }
}
