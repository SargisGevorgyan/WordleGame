package com.sargisgevorgyan.wordlegame.monetization

import android.app.Activity
import android.content.Context
import androidx.annotation.StringRes
import androidx.core.content.edit
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.consumePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.sargisgevorgyan.wordlegame.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume

/**
 * Google Play Billing (Billing Library 7): Remove Ads (one-time), hint packs
 * (consumable) and the Wordy Pro subscription. Mirrors iOS `StoreManager`.
 *
 * - Purchases are re-queried at launch and on every resume, which restores
 *   Remove Ads / Pro on a new device, picks up pending purchases that completed
 *   and notices a Pro subscription that lapsed.
 * - Hint packs are granted once per purchase token ([HintWallet]) and then consumed;
 *   Remove Ads and Pro are acknowledged (Play refunds unacknowledged buys after 3 days).
 * - Entitlements are cached so ads don't flash on launch before Play answers.
 *
 * Purchases are verified on device only (no server), as on iOS.
 */
class BillingManager(context: Context, private val wallet: HintWallet) : PurchasesUpdatedListener {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val prefs = context.getSharedPreferences("wordle", Context.MODE_PRIVATE)
    private val client = BillingClient.newBuilder(context.applicationContext)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()
    private val connectLock = Mutex()
    private val refreshLock = Mutex()

    private val _products = MutableStateFlow<Map<String, ProductDetails>>(emptyMap())
    val products: StateFlow<Map<String, ProductDetails>> = _products.asStateFlow()

    private val _entitlements = MutableStateFlow(
        Entitlements(ownsRemoveAds = prefs.getBoolean(KEY_REMOVE_ADS, false), isPro = prefs.getBoolean(KEY_PRO, false)),
    )
    val entitlements: StateFlow<Entitlements> = _entitlements.asStateFlow()

    private val _purchasing = MutableStateFlow(false)
    val purchasing: StateFlow<Boolean> = _purchasing.asStateFlow()

    /** Short user-facing messages (string resources) about purchases. */
    private val _messages = MutableSharedFlow<Int>(extraBufferCapacity = 4)
    val messages: SharedFlow<Int> = _messages.asSharedFlow()

    /** Hint packs granted, for a "+N hints" toast. */
    private val _hintGrants = MutableSharedFlow<Int>(extraBufferCapacity = 4)
    val hintGrants: SharedFlow<Int> = _hintGrants.asSharedFlow()

    // Prices

    fun price(productId: String): String? = _products.value[productId]?.oneTimePurchaseOfferDetails?.formattedPrice

    fun proPrice(plan: Products.ProPlan): String? = proOffer(plan)?.basePhase()?.formattedPrice

    fun proPriceMicros(plan: Products.ProPlan): Long? = proOffer(plan)?.basePhase()?.priceAmountMicros

    private fun proOffer(plan: Products.ProPlan): ProductDetails.SubscriptionOfferDetails? {
        val offers = _products.value[Products.PRO]?.subscriptionOfferDetails
            ?.filter { it.basePlanId == plan.basePlanId }.orEmpty()
        // Prefer the plain base plan; fall back to any offer on it.
        return offers.firstOrNull { it.offerId == null } ?: offers.firstOrNull()
    }

    private fun ProductDetails.SubscriptionOfferDetails.basePhase() = pricingPhases.pricingPhaseList.lastOrNull()

    // Refresh / restore

    /** Loads products and re-reads owned purchases. Called at launch and on every resume. */
    fun refresh() {
        scope.launch { refreshNow(reportRestore = false) }
    }

    fun restorePurchases() {
        scope.launch { refreshNow(reportRestore = true) }
    }

    private suspend fun refreshNow(reportRestore: Boolean) = refreshLock.withLock {
        if (!ensureConnected()) {
            if (reportRestore) _messages.tryEmit(R.string.store_unavailable)
            return@withLock
        }
        if (_products.value.isEmpty()) loadProducts()

        val inApp = client.queryPurchasesAsync(purchasesParams(ProductType.INAPP))
        val subs = client.queryPurchasesAsync(purchasesParams(ProductType.SUBS))
        val ok = inApp.billingResult.responseCode == BillingResponseCode.OK &&
            subs.billingResult.responseCode == BillingResponseCode.OK
        if (!ok) {
            if (reportRestore) _messages.tryEmit(R.string.restore_failed)
            return@withLock
        }
        val purchases = inApp.purchasesList + subs.purchasesList
        process(purchases)
        val owned = purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.flatMap { it.products }
        setEntitlements(Entitlements.resolve(owned))
        if (reportRestore) {
            _messages.tryEmit(if (_entitlements.value.isAdFree) R.string.purchases_restored else R.string.no_purchases_found)
        }
    }

    private suspend fun loadProducts() {
        val found = mutableMapOf<String, ProductDetails>()
        for ((type, ids) in listOf(ProductType.INAPP to Products.inApp, ProductType.SUBS to Products.subscriptions)) {
            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(ids.map {
                    QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(type).build()
                })
                .build()
            val result = client.queryProductDetails(params)
            if (result.billingResult.responseCode == BillingResponseCode.OK) {
                result.productDetailsList.orEmpty().forEach { found[it.productId] = it }
            }
        }
        _products.value = found
    }

    // Purchasing

    fun buy(activity: Activity, productId: String) = launchFlow(activity, productId, plan = null)

    fun buyPro(activity: Activity, plan: Products.ProPlan) = launchFlow(activity, Products.PRO, plan)

    /** [plan] picks the subscription base plan; null for one-time products. */
    private fun launchFlow(activity: Activity, productId: String, plan: Products.ProPlan?) {
        scope.launch {
            if (!ensureConnected()) {
                _messages.tryEmit(R.string.store_unavailable)
                return@launch
            }
            if (_products.value.isEmpty()) loadProducts()
            val details = _products.value[productId]
            val offerToken = plan?.let { proOffer(it)?.offerToken }
            if (details == null || (plan != null && offerToken == null)) {
                _messages.tryEmit(R.string.product_unavailable)
                return@launch
            }

            val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .apply { if (offerToken != null) setOfferToken(offerToken) }
                .build()
            val flow = BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(productParams)).build()
            val result = client.launchBillingFlow(activity, flow)
            if (result.responseCode == BillingResponseCode.OK) {
                _purchasing.value = true
            } else if (result.responseCode == BillingResponseCode.ITEM_ALREADY_OWNED) {
                refreshNow(reportRestore = false)
            } else {
                _messages.tryEmit(R.string.purchase_failed)
            }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        _purchasing.value = false
        when (result.responseCode) {
            BillingResponseCode.OK -> {
                if (purchases.orEmpty().any { it.purchaseState == Purchase.PurchaseState.PENDING }) {
                    _messages.tryEmit(R.string.purchase_pending)
                }
                // Re-query rather than trusting the callback list: one path grants,
                // consumes, acknowledges and recomputes entitlements.
                refresh()
            }
            BillingResponseCode.USER_CANCELED -> Unit
            BillingResponseCode.ITEM_ALREADY_OWNED -> refresh()
            else -> _messages.tryEmit(R.string.purchase_failed)
        }
    }

    /** Grants + consumes hint packs, acknowledges Remove Ads / Pro. Pending purchases wait. */
    private suspend fun process(purchases: List<Purchase>) {
        for (purchase in purchases) {
            if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) continue
            val hints = purchase.products.sumOf { Products.hintsFor(it) ?: 0 } * purchase.quantity
            if (hints > 0) {
                if (wallet.grantPurchase(purchase.purchaseToken, hints)) _hintGrants.tryEmit(hints)
                val consumed = client.consumePurchase(
                    ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build(),
                )
                if (consumed.billingResult.responseCode == BillingResponseCode.OK) {
                    wallet.forgetPurchase(purchase.purchaseToken)
                }
            } else if (!purchase.isAcknowledged) {
                client.acknowledgePurchase(
                    AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build(),
                )
            }
        }
    }

    private fun setEntitlements(value: Entitlements) {
        _entitlements.value = value
        prefs.edit {
            putBoolean(KEY_REMOVE_ADS, value.ownsRemoveAds)
            putBoolean(KEY_PRO, value.isPro)
        }
    }

    // Connection

    private suspend fun ensureConnected(): Boolean = connectLock.withLock {
        if (client.isReady) return@withLock true
        suspendCancellableCoroutine { cont ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (cont.isActive) cont.resume(result.responseCode == BillingResponseCode.OK)
                }

                // The next refresh / purchase reconnects.
                override fun onBillingServiceDisconnected() {
                    if (cont.isActive) cont.resume(false)
                }
            })
        }
    }

    private fun purchasesParams(type: String) = QueryPurchasesParams.newBuilder().setProductType(type).build()

    private companion object {
        const val KEY_REMOVE_ADS = "ownsRemoveAds"
        const val KEY_PRO = "isPro"
    }
}
