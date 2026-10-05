//
//  StoreManager.swift
//  WordleGame
//
//  StoreKit 2 wrapper.
//
//  Products:
//   • "Remove Ads"  — non-consumable  (com.sargisgevorgyan.wordlegame.removeads)      → UserDefaults["isAdFree"]
//   • Hint packs    — consumables     (com.sargisgevorgyan.wordlegame.hints.five / .twenty) → onHintsGranted(count)
//   • Wordy Pro     — auto-renewable  (com.sargisgevorgyan.wordlegame.pro.monthly / .yearly,
//                     subscription group "Wordy Pro") → no ads + unlimited hints
//                     → UserDefaults["isAdFree"] + UserDefaults["isPro"]
//
//  - Loads with `Product.products(for:)`, purchases with `product.purchase()`,
//    verifies the `VerificationResult`, listens to `Transaction.updates`.
//  - Restores Remove Ads / Pro with `AppStore.sync()` + `Transaction.currentEntitlements`.
//  - Pro expiry isn't pushed by StoreKit, so the app calls `refreshEntitlements()`
//    whenever it becomes active.
//
//  Testing in the Simulator: select the bundled `Products.storekit` file as the
//  StoreKit Configuration in your scheme (Edit Scheme > Run > Options).
//

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    /// 🔧 Replace with your real App Store product identifiers.
    static let removeAdsProductID = "com.sargisgevorgyan.wordlegame.removeads"

    /// Consumable hint packs.
    enum HintPack: String, CaseIterable, Identifiable {
        case five   = "com.sargisgevorgyan.wordlegame.hints.five"
        case twenty = "com.sargisgevorgyan.wordlegame.hints.twenty"

        var id: String { rawValue }
        var hints: Int { self == .five ? 5 : 20 }
        var fallbackPrice: String { self == .five ? "$0.99" : "$2.99" }

        static func hints(forProductID id: String) -> Int? {
            HintPack(rawValue: id)?.hints
        }
    }

    /// Auto-renewable "Wordy Pro" plans (one subscription group).
    enum ProPlan: String, CaseIterable, Identifiable {
        case monthly = "com.sargisgevorgyan.wordlegame.pro.monthly"
        case yearly  = "com.sargisgevorgyan.wordlegame.pro.yearly"

        var id: String { rawValue }
        var fallbackPrice: String { self == .monthly ? "$1.99" : "$9.99" }
    }

    /// What the player owns, resolved from their current entitlements.
    struct Entitlements: Equatable {
        var ownsRemoveAds = false
        var isPro = false
        var isAdFree: Bool { ownsRemoveAds || isPro }

        struct Item {
            let productID: String
            let isRevoked: Bool
            let expirationDate: Date?
        }

        /// Pure so it can be unit tested without StoreKit.
        static func resolve(_ items: [Item], now: Date = .now) -> Entitlements {
            var result = Entitlements()
            for item in items where !item.isRevoked {
                if item.productID == StoreManager.removeAdsProductID {
                    result.ownsRemoveAds = true
                } else if ProPlan(rawValue: item.productID) != nil,
                          (item.expirationDate ?? .distantFuture) > now {
                    result.isPro = true
                }
            }
            return result
        }
    }

    /// Linked from the Pro paywall (required for subscriptions by App Review).
    /// Apple's standard EULA; swap in your own terms if you publish them.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// 🔧 Replace with your hosted privacy policy (also enter it in App Store Connect).
    static let privacyPolicyURL = URL(string: "https://github.com/SargisGevorgyan/WordleGame/blob/main/PRIVACY.md")!

    static let isProKey = "isPro"
    static let isAdFreeKey = "isAdFree"

    enum PurchaseState: Equatable {
        case idle, loading, purchasing, success, restored, failed(String)
    }

    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var hintProducts: [Product] = []
    @Published private(set) var state: PurchaseState = .idle
    @Published private(set) var proProducts: [Product] = []
    @Published private(set) var isAdFree: Bool = UserDefaults.standard.bool(forKey: StoreManager.isAdFreeKey)
    @Published private(set) var isPro: Bool = UserDefaults.standard.bool(forKey: StoreManager.isProKey)
    @Published private(set) var ownsRemoveAds = false

    /// Called with the number of hints to grant after a successful consumable
    /// purchase (wired to `GameViewModel.addHints` by the app). Hints granted
    /// before this is set (e.g. an interrupted purchase delivered at launch) are
    /// held and handed over as soon as it is assigned.
    var onHintsGranted: ((Int) -> Void)? {
        didSet { flushPendingHints() }
    }
    private var pendingHints = 0

    private var updatesTask: Task<Void, Never>?
    private var grantedTransactionIDs = Set<UInt64>()

    init() {
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Loading

    func loadProducts() async {
        state = .loading
        do {
            let ids = [Self.removeAdsProductID]
                + HintPack.allCases.map(\.rawValue)
                + ProPlan.allCases.map(\.rawValue)
            let products = try await Product.products(for: ids)
            removeAdsProduct = products.first { $0.id == Self.removeAdsProductID }
            hintProducts = products
                .filter { HintPack(rawValue: $0.id) != nil }
                .sorted { $0.price < $1.price }
            proProducts = products
                .filter { ProPlan(rawValue: $0.id) != nil }
                .sorted { $0.price < $1.price }
            state = .idle
        } catch {
            state = .failed(String(localized: "Couldn't load products."))
        }
    }

    var removeAdsDisplayPrice: String {
        removeAdsProduct?.displayPrice ?? "$1.99"
    }

    func proProduct(_ plan: ProPlan) -> Product? {
        proProducts.first { $0.id == plan.rawValue }
    }

    func proDisplayPrice(_ plan: ProPlan) -> String {
        proProduct(plan)?.displayPrice ?? plan.fallbackPrice
    }

    func hintCount(for product: Product) -> Int {
        HintPack.hints(forProductID: product.id) ?? 0
    }

    // MARK: - Purchase — Remove Ads (non-consumable)

    func purchaseRemoveAds() async {
        guard let product = removeAdsProduct else {
            state = .failed(String(localized: "Product unavailable."))
            return
        }
        await purchase(product) { [weak self] _ in
            await self?.refreshEntitlements()
        }
    }

    // MARK: - Purchase — Pro (auto-renewable subscription)

    func purchasePro(_ plan: ProPlan) async {
        guard let product = proProduct(plan) else {
            state = .failed(String(localized: "Product unavailable."))
            return
        }
        await purchase(product) { [weak self] _ in
            await self?.refreshEntitlements()
        }
    }

    // MARK: - Purchase — Hint packs (consumable)

    /// Returns `true` when hints were granted.
    @discardableResult
    func purchaseHints(_ product: Product) async -> Bool {
        var granted = false
        await purchase(product) { [weak self] transaction in
            granted = self?.grantHints(for: transaction) ?? false
        }
        return granted
    }

    // MARK: - Shared purchase flow

    private func purchase(_ product: Product,
                          onVerified: @escaping (Transaction) async -> Void) async {
        state = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await onVerified(transaction)
                await transaction.finish()
                state = .success
                Haptics.shared.notify(.success)
            case .userCancelled:
                state = .idle
            case .pending:
                state = .failed(String(localized: "Purchase pending approval."))
            @unknown default:
                state = .idle
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        state = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            state = isAdFree || isPro ? .restored : .failed(String(localized: "No previous purchases found."))
        } catch {
            state = .failed(String(localized: "Restore failed."))
        }
    }

    // MARK: - Entitlements / transactions

    func refreshEntitlements() async {
        var items: [Entitlements.Item] = []
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            items.append(.init(productID: transaction.productID,
                               isRevoked: transaction.revocationDate != nil,
                               expirationDate: transaction.expirationDate))
        }
        apply(Entitlements.resolve(items))
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self, case .verified(let transaction) = update else { continue }
                if HintPack(rawValue: transaction.productID) == nil {
                    await self.refreshEntitlements()   // Remove Ads / Pro bought, renewed, refunded…
                } else {
                    _ = await self.grantHints(for: transaction)   // interrupted / external buys
                }
                await transaction.finish()
            }
        }
    }

    /// Grants hint-pack content exactly once per transaction id.
    @discardableResult
    private func grantHints(for transaction: Transaction) -> Bool {
        guard let count = HintPack.hints(forProductID: transaction.productID),
              !grantedTransactionIDs.contains(transaction.id) else { return false }
        grantedTransactionIDs.insert(transaction.id)
        pendingHints += count
        flushPendingHints()
        return true
    }

    private func flushPendingHints() {
        guard pendingHints > 0, let onHintsGranted else { return }
        let count = pendingHints
        pendingHints = 0
        onHintsGranted(count)
    }

    private func apply(_ entitlements: Entitlements) {
        UserDefaults.standard.set(entitlements.isAdFree, forKey: Self.isAdFreeKey)
        UserDefaults.standard.set(entitlements.isPro, forKey: Self.isProKey)
        if isAdFree != entitlements.isAdFree { isAdFree = entitlements.isAdFree }
        if isPro != entitlements.isPro { isPro = entitlements.isPro }
        if ownsRemoveAds != entitlements.ownsRemoveAds { ownsRemoveAds = entitlements.ownsRemoveAds }
    }

    // MARK: - Verification

    private enum StoreError: Error { case failedVerification }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:         throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }
}
