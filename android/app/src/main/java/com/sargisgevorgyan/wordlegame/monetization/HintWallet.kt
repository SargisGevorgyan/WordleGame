package com.sargisgevorgyan.wordlegame.monetization

import android.content.Context
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The player's hint balance, shared by the game and by Play Billing so a hint
 * pack bought while no game screen is open is never lost.
 *
 * Purchased hints are granted once per purchase token. The token is saved in
 * the same write as the new balance, so a crash between granting and consuming
 * the purchase can't grant it twice; it is forgotten once Play has consumed it.
 */
class HintWallet(context: Context) {
    private val prefs = context.getSharedPreferences("wordle", Context.MODE_PRIVATE)
    private val _hints = MutableStateFlow(prefs.getInt(KEY_HINTS, Economy.STARTING_HINTS))
    val hints: StateFlow<Int> = _hints.asStateFlow()

    @Synchronized
    fun set(value: Int) {
        val clamped = value.coerceIn(0, Economy.MAX_HINTS)
        _hints.value = clamped
        prefs.edit { putInt(KEY_HINTS, clamped) }
    }

    fun add(count: Int) = set(hints.value + count)

    /** Returns false when this purchase was already granted. */
    @Synchronized
    fun grantPurchase(purchaseToken: String, count: Int): Boolean {
        val granted = grantedTokens()
        if (purchaseToken in granted) return false
        val clamped = (hints.value + count).coerceIn(0, Economy.MAX_HINTS)
        prefs.edit(commit = true) {
            putInt(KEY_HINTS, clamped)
            putStringSet(KEY_GRANTED_TOKENS, granted + purchaseToken)
        }
        _hints.value = clamped
        return true
    }

    /** Called after Play confirms the purchase was consumed. */
    @Synchronized
    fun forgetPurchase(purchaseToken: String) {
        val granted = grantedTokens()
        if (purchaseToken in granted) prefs.edit { putStringSet(KEY_GRANTED_TOKENS, granted - purchaseToken) }
    }

    private fun grantedTokens(): Set<String> = prefs.getStringSet(KEY_GRANTED_TOKENS, null).orEmpty().toSet()

    private companion object {
        const val KEY_HINTS = "hintsRemaining"
        const val KEY_GRANTED_TOKENS = "grantedHintPurchases"
    }
}
