import Foundation
import StoreKit

/// Lumi Plus 内购产品（ID 与 App Store Connect / `Lumi.storekit` 一致）。
/// 当前仅**月订阅**一档。
enum PlusProduct: String, CaseIterable {
    case monthly = "com.lumi.plus.monthly"

    var sortOrder: Int { 0 }
    var isSubscription: Bool { true }

    /// 计划名（本地化键，源中文）。
    var title: String { String(localized: "按月") }
}

/// Plus 权益 + 内购。**当前用 StoreKit 2 原生实现**；业务层只读 `isPlus` / `products`，
/// 不直接碰 StoreKit。日后若换 RevenueCat（为 Android 跨平台 entitlement 打底），
/// 只需替换 `refreshEntitlement()` 与购买/恢复内部实现，**业务层零改动**——见各「RC 迁移点」注释。
@MainActor
final class PlusStore: ObservableObject {
    static let shared = PlusStore()

    /// 是否已解锁 Plus（订阅未过期 或 终身买断）。业务层唯一需要读的开关。
    @Published private(set) var isPlus = false
    /// 当前订阅到期 / 下次续订日期（终身买断为 nil）。
    @Published private(set) var expirationDate: Date?
    /// 是否已开启自动续订。
    @Published private(set) var autoRenewOn = false
    /// 三个可售产品（已按 月 → 年 → 终身 排序）。
    @Published private(set) var products: [Product] = []
    @Published private(set) var loadingProducts = false
    @Published private(set) var purchasing = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()   // 监听续订 / Ask-to-Buy / 跨设备购买
    }

    deinit { updatesTask?.cancel() }

    /// App 启动时调用一次：拉产品 + 对齐权益。
    func start() async {
        await loadProducts()
        await refreshEntitlement()
    }

    // MARK: - 产品

    func loadProducts() async {
        guard products.isEmpty else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let fetched = try await Product.products(for: PlusProduct.allCases.map(\.rawValue))
            products = fetched.sorted {
                (PlusProduct(rawValue: $0.id)?.sortOrder ?? 99) < (PlusProduct(rawValue: $1.id)?.sortOrder ?? 99)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 购买 / 恢复

    /// 购买；成功并解锁返回 true。userCancelled / pending 返回 false。
    func purchase(_ product: Product) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await transaction.finish()
                await refreshEntitlement()
                // 兜底：本地 StoreKit 测试里 currentEntitlements 偶尔在购买刚成功的瞬间还没收录，
                // 直接信任这笔刚验签通过的交易，避免「订阅成功但状态没切」。
                if !isPlus, isEntitling(transaction) { isPlus = true }
                return isPlus
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// 恢复购买（绑 Apple ID）。
    func restore() async {
        do { try await AppStore.sync() }
        catch { lastError = error.localizedDescription }
        await refreshEntitlement()
    }

    // MARK: - 权益（RC 迁移点：换成 RevenueCat `customerInfo.entitlements["plus"].isActive` 即可）

    func refreshEntitlement() async {
        var active = false
        var expiry: Date?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verify(result), isEntitling(transaction) else { continue }
            active = true
            expiry = transaction.expirationDate          // 订阅有到期；终身为 nil
        }
        isPlus = active
        expirationDate = expiry
        await refreshRenewalState()
    }

    /// 读取自动续订状态（StoreKit 2 订阅状态流）。
    private func refreshRenewalState() async {
        guard isPlus,
              let sub = products.first(where: { PlusProduct(rawValue: $0.id) != nil })?.subscription,
              let statuses = try? await sub.status else { autoRenewOn = false; return }
        for status in statuses {
            guard case .verified(let renewal) = status.renewalInfo else { continue }
            if status.state == .subscribed || status.state == .inGracePeriod {
                autoRenewOn = renewal.willAutoRenew
                return
            }
        }
        autoRenewOn = false
    }

    /// 这笔交易是否当前有效（我们的产品 · 未撤销 · 订阅未过期 / 买断永久）。
    private func isEntitling(_ transaction: Transaction) -> Bool {
        guard PlusProduct(rawValue: transaction.productID) != nil,
              transaction.revocationDate == nil else { return false }
        if let expiry = transaction.expirationDate { return expiry > Date() }
        return true
    }

    // MARK: - 内部

    /// RC 迁移点：换 RevenueCat 后这里改为监听其 `customerInfo` 流。
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? self.verify(update) {
                    await transaction.finish()
                    await self.refreshEntitlement()
                }
            }
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe):       return safe
        }
    }
}
