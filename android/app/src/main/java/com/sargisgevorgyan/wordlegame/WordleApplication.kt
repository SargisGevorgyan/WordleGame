package com.sargisgevorgyan.wordlegame

import android.app.Application
import com.sargisgevorgyan.wordlegame.monetization.AdsManager
import com.sargisgevorgyan.wordlegame.monetization.BillingManager
import com.sargisgevorgyan.wordlegame.monetization.HintWallet

/** Holds the process-wide monetization objects (they outlive activity recreation). */
class WordleApplication : Application() {
    lateinit var hints: HintWallet
        private set
    lateinit var billing: BillingManager
        private set
    lateinit var ads: AdsManager
        private set

    override fun onCreate() {
        super.onCreate()
        // The wallet exists before billing starts, so restored hint purchases always land.
        hints = HintWallet(this)
        billing = BillingManager(this, hints)
        ads = AdsManager(this)
    }
}
