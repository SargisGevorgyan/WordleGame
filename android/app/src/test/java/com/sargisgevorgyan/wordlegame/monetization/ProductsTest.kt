package com.sargisgevorgyan.wordlegame.monetization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductsTest {

    @Test
    fun nothingOwnedShowsAds() {
        val e = Entitlements.resolve(emptyList())
        assertFalse(e.isAdFree)
        assertFalse(e.isPro)
    }

    @Test
    fun removeAdsIsAdFreeButNotPro() {
        val e = Entitlements.resolve(listOf(Products.REMOVE_ADS, Products.HINTS_FIVE))
        assertTrue(e.isAdFree)
        assertFalse(e.isPro)
    }

    @Test
    fun proIsAdFreeAndPro() {
        val e = Entitlements.resolve(listOf(Products.PRO))
        assertTrue(e.isPro)
        assertTrue(e.isAdFree)
        assertFalse(e.ownsRemoveAds)
    }

    @Test
    fun hintPacksMatchIos() {
        assertEquals(5, Products.hintsFor(Products.HINTS_FIVE))
        assertEquals(20, Products.hintsFor(Products.HINTS_TWENTY))
        assertNull(Products.hintsFor(Products.REMOVE_ADS))
        assertNull(Products.hintsFor(Products.PRO))
    }

    @Test
    fun interstitialEveryThirdRoundOnce() {
        val pacer = InterstitialPacer(3)
        val shown = (1..9).map { pacer.roundFinished(); pacer.consumeDue(isAdFree = false) }
        assertEquals(listOf(false, false, true, false, false, true, false, false, true), shown)
        assertFalse(pacer.consumeDue(isAdFree = false))
    }

    @Test
    fun adFreePlayersNeverGetInterstitials() {
        val pacer = InterstitialPacer(1)
        repeat(3) {
            pacer.roundFinished()
            assertFalse(pacer.consumeDue(isAdFree = true))
        }
    }

    @Test
    fun yearlySavings() {
        assertEquals(58, yearlySavingsPercent(1_990_000, 9_990_000))
        assertNull(yearlySavingsPercent(1_000_000, 12_000_000))
        assertNull(yearlySavingsPercent(0, 9_990_000))
    }
}
