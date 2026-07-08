import Foundation
import StoreKit

// ─────────────────────────────────────────────────────────────
//  PackStore —— 资源包权益与购买（v1.2，混合制 D1/D5）。
//
//  · free  → 人人可用（解锁条件是玩法，如地区票限本国足迹）；
//  · plus  → 终身会员免费领（随 com.lumi.plus.lifetime）；
//  · paid  → 人人单买 Non-Consumable `com.lumi.pack.<id>`，Plus 享折扣
//            （折扣用 ASC 同产品双价格档/促销实现，客户端只认拥有与否）。
//  购买凭据在 Apple（Transaction.currentEntitlements）；云端记录随 v1.2.1。
// ─────────────────────────────────────────────────────────────

@MainActor
final class PackStore: ObservableObject {
    static let shared = PackStore()

    /// 已购的 pack 产品 id（com.lumi.pack.*，来自 StoreKit 当前权益）。
    @Published private(set) var ownedProductIDs: Set<String> = []
    /// 可购产品（按需拉取；ASC 未建产品时为空 → UI 显示「即将上架」）。
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var purchasing = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update {
                    await t.finish()
                    await self?.refreshOwned()
                }
            }
        }
    }
    deinit { updatesTask?.cancel() }

    /// 包是否已拥有（可在编辑器/图鉴中使用）。
    func owns(_ pack: ContentPack) -> Bool {
        switch pack.pricing {
        case .free: return true
        case .plus: return PlusStore.shared.isPlus
        case .paid: return ownedProductIDs.contains(pack.productID ?? "com.lumi.pack.\(pack.id)")
        }
    }

    /// 刷新已购集合（启动 / 交易更新时）。
    func refreshOwned() async {
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement, t.productID.hasPrefix("com.lumi.pack.") {
                owned.insert(t.productID)
            }
        }
        ownedProductIDs = owned
    }

    /// 拉取付费包的商店产品（详情页展示价格用）。
    func loadProducts(for packs: [ContentPack]) async {
        let ids = packs.compactMap { p -> String? in
            guard case .paid = p.pricing else { return nil }
            return p.productID ?? "com.lumi.pack.\(p.id)"
        }
        guard !ids.isEmpty else { return }
        guard let fetched = try? await Product.products(for: ids) else { return }
        for p in fetched { products[p.id] = p }
    }

    /// 购买付费包；成功返回 true。
    func purchase(_ pack: ContentPack) async -> Bool {
        let pid = pack.productID ?? "com.lumi.pack.\(pack.id)"
        guard let product = products[pid] else {
            lastError = String(localized: "该资源包暂未上架，敬请期待")
            return false
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified(let t) = verification {
                await t.finish()
                ownedProductIDs.insert(t.productID)
                Haptics.success()
                return true
            }
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// 恢复购买（与 Plus 恢复并列入口）。
    func restore() async {
        try? await AppStore.sync()
        await refreshOwned()
    }
}
