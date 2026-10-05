package com.sargisgevorgyan.wordlegame.monetization

import kotlin.math.roundToInt

/**
 * Google Play product IDs. They mirror the iOS App Store IDs; create them in
 * Play Console with exactly these names.
 */
object Products {
    /** One-time, non-consumable: removes banner and interstitial ads. */
    const val REMOVE_ADS = "com.sargisgevorgyan.wordlegame.removeads"
    /** Consumable hint packs. */
    const val HINTS_FIVE = "com.sargisgevorgyan.wordlegame.hints.five"
    const val HINTS_TWENTY = "com.sargisgevorgyan.wordlegame.hints.twenty"
    /** "Wordy Pro" subscription (no ads + unlimited hints) with two base plans. */
    const val PRO = "com.sargisgevorgyan.wordlegame.pro"

    enum class ProPlan(val basePlanId: String) { MONTHLY("monthly"), YEARLY("yearly") }

    val hintPacks = linkedMapOf(HINTS_FIVE to 5, HINTS_TWENTY to 20)
    val inApp = listOf(REMOVE_ADS) + hintPacks.keys
    val subscriptions = listOf(PRO)

    fun hintsFor(productId: String): Int? = hintPacks[productId]
}

/** The hint and ad economy, kept the same as iOS (`GameViewModel`, `AdManager`). */
object Economy {
    const val STARTING_HINTS = 3
    /** A win grants +1 hint, but never above this. */
    const val FREE_HINT_CEILING = 5
    const val MAX_HINTS = 99
    const val HINTS_PER_REWARDED_AD = 1
    const val ROUNDS_PER_INTERSTITIAL = 3
}

/** What the player owns, resolved from their active Play purchases. */
data class Entitlements(val ownsRemoveAds: Boolean = false, val isPro: Boolean = false) {
    val isAdFree get() = ownsRemoveAds || isPro

    companion object {
        /** [ownedProductIds]: products of purchases in the PURCHASED state (not pending). */
        fun resolve(ownedProductIds: Collection<String>) = Entitlements(
            ownsRemoveAds = Products.REMOVE_ADS in ownedProductIds,
            isPro = Products.PRO in ownedProductIds,
        )
    }
}

/** Shows an interstitial after every Nth finished round, on the following "Play again". */
class InterstitialPacer(private val roundsPerAd: Int = Economy.ROUNDS_PER_INTERSTITIAL) {
    private var finishedRounds = 0
    private var due = false

    fun roundFinished() {
        finishedRounds++
        if (finishedRounds % roundsPerAd == 0) due = true
    }

    /** True once per due interstitial; ad-free players never get one (and the slot is dropped). */
    fun consumeDue(isAdFree: Boolean): Boolean {
        val show = due && !isAdFree
        due = false
        return show
    }
}

/** "Save 58%" for a yearly plan vs. 12 monthly payments, or null if it isn't cheaper. */
fun yearlySavingsPercent(monthlyMicros: Long, yearlyMicros: Long): Int? {
    if (monthlyMicros <= 0 || yearlyMicros <= 0) return null
    val percent = ((1 - yearlyMicros.toDouble() / (monthlyMicros * 12)) * 100).roundToInt()
    return percent.takeIf { it > 0 }
}
