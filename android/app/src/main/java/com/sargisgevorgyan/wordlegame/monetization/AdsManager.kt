package com.sargisgevorgyan.wordlegame.monetization

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import com.sargisgevorgyan.wordlegame.BuildConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * AdMob (banner, interstitial, rewarded) behind Google's UMP consent flow.
 * Mirrors iOS `AdManager`.
 *
 * Nothing is requested until UMP says ads may be requested: consent is gathered
 * (EEA / UK / Switzerland get the form) and only then is the SDK started and the
 * first ads loaded. There is no "free reward" fallback: with no ad ready, the
 * rewarded button is simply disabled.
 */
class AdsManager(context: Context) {

    private val appContext = context.applicationContext
    private val consent: ConsentInformation = UserMessagingPlatform.getConsentInformation(appContext)
    private var started = false

    private val _canRequestAds = MutableStateFlow(false)
    /** True once consent allows ads and the SDK is started (gates the banner). */
    val canRequestAds: StateFlow<Boolean> = _canRequestAds.asStateFlow()

    private val _privacyOptionsRequired = MutableStateFlow(false)
    /** Settings shows "Privacy choices" when UMP says the user must be able to change consent. */
    val privacyOptionsRequired: StateFlow<Boolean> = _privacyOptionsRequired.asStateFlow()

    private val _rewardedReady = MutableStateFlow(false)
    val rewardedReady: StateFlow<Boolean> = _rewardedReady.asStateFlow()

    private val pacer = InterstitialPacer()
    private var interstitial: InterstitialAd? = null
    private var rewarded: RewardedAd? = null
    private var loadingRewarded = false
    private var rewardedOnScreen = false

    // Consent + start-up

    /** Call from the activity on every launch: UMP re-checks consent each session. */
    fun gatherConsent(activity: Activity) {
        val params = ConsentRequestParameters.Builder().build()
        consent.requestConsentInfoUpdate(
            activity,
            params,
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                    error?.let { Log.w(TAG, "Consent form: ${it.message}") }
                    _privacyOptionsRequired.value = consent.privacyOptionsRequirementStatus ==
                        ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
                    startIfAllowed()
                }
            },
            { error ->
                Log.w(TAG, "Consent info update failed: ${error.message}")
                startIfAllowed()
            },
        )
        // Consent from a previous session lets ads start without waiting for the update.
        startIfAllowed()
    }

    fun showPrivacyOptions(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { error ->
            error?.let { Log.w(TAG, "Privacy options: ${it.message}") }
        }
    }

    private fun startIfAllowed() {
        if (started || !consent.canRequestAds()) return
        started = true
        MobileAds.initialize(appContext) {}
        _canRequestAds.value = true
        loadInterstitial()
        loadRewarded()
    }

    // Interstitial

    /** Called once per finished round. */
    fun roundFinished() = pacer.roundFinished()

    /** Called on "Play again": shows the interstitial when one is due (every 3rd round). */
    fun maybeShowInterstitial(activity: Activity, isAdFree: Boolean) {
        if (!pacer.consumeDue(isAdFree)) return
        val ad = interstitial ?: return loadInterstitial()
        interstitial = null
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() = loadInterstitial()
            override fun onAdFailedToShowFullScreenContent(error: AdError) = loadInterstitial()
        }
        ad.show(activity)
    }

    private fun loadInterstitial() {
        if (!started || interstitial != null) return
        InterstitialAd.load(
            appContext,
            BuildConfig.ADMOB_INTERSTITIAL_ID,
            AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitial = ad
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    Log.w(TAG, "Interstitial failed to load: ${error.message}")
                }
            },
        )
    }

    // Rewarded (earn a hint)

    /** Retries a failed load (offline, no fill) when the hint store opens. */
    fun loadRewardedIfNeeded() {
        if (rewarded == null && !loadingRewarded && !rewardedOnScreen) loadRewarded()
    }

    /** [onFinished] runs once, when the ad closes, with the hints to grant (0 if not earned). */
    fun showRewarded(activity: Activity, onFinished: (Int) -> Unit) {
        val ad = rewarded
        if (ad == null || rewardedOnScreen) {
            loadRewardedIfNeeded()
            onFinished(0)
            return
        }
        // A rewarded ad can be shown once: drop it now, load the next when it closes.
        rewarded = null
        _rewardedReady.value = false
        rewardedOnScreen = true
        var earned = false
        fun finish() {
            rewardedOnScreen = false
            onFinished(if (earned) Economy.HINTS_PER_REWARDED_AD else 0)
            loadRewarded()
        }
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() = finish()
            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                Log.w(TAG, "Rewarded failed to show: ${error.message}")
                finish()
            }
        }
        ad.show(activity) { earned = true }
    }

    private fun loadRewarded() {
        if (!started) return
        loadingRewarded = true
        RewardedAd.load(
            appContext,
            BuildConfig.ADMOB_REWARDED_ID,
            AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    loadingRewarded = false
                    rewarded = ad
                    _rewardedReady.value = true
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    loadingRewarded = false
                    _rewardedReady.value = false
                    Log.w(TAG, "Rewarded failed to load: ${error.message}")
                }
            },
        )
    }

    private companion object {
        const val TAG = "AdsManager"
    }
}
