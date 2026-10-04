package com.sargisgevorgyan.wordlegame.monetization

/** Links shown next to purchases. */
object Links {
    /** 🔧 Replace with your hosted privacy policy (also enter it in Play Console). Same as iOS. */
    const val PRIVACY_POLICY = "https://github.com/SargisGevorgyan/WordleGame/blob/main/PRIVACY.md"

    fun manageSubscription(packageName: String) =
        "https://play.google.com/store/account/subscriptions?sku=${Products.PRO}&package=$packageName"
}
