import Foundation

/// 本地热点推荐（Map 页「本地」视图下半区）：官方 / 平台运营位，**服务端下发**。
/// 数据源：Supabase Storage 公共桶 `highlights/local.json`（与 PackCatalog.refreshRemote 同模式）；
/// 未配置后端 / 拉取失败 / 尚未上架内容 → `items = []`，UI 显示「敬请期待」空态。
@MainActor
final class LocalHighlights: ObservableObject {
    static let shared = LocalHighlights()

    struct Item: Codable, Identifiable {
        let id: String
        let title: String
        var subtitle: String? = nil
        var imageURL: String? = nil
        var lat: Double? = nil
        var lon: Double? = nil
    }

    @Published private(set) var items: [Item] = []

    private init() {}

    /// 拉取运营位内容；失败静默（空态兜底，页面永不报错）。
    func refresh() async {
        guard let base = LumiPostConfig.url,
              let url = URL(string: base.absoluteString + "/storage/v1/object/public/highlights/local.json")
        else { return }
        var req = URLRequest(url: url); req.timeoutInterval = 20
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONDecoder().decode([Item].self, from: data) else { return }
        items = list
    }
}
