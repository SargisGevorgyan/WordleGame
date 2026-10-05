package com.sargisgevorgyan.wordlegame

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.sargisgevorgyan.wordlegame.games.PlayGamesService
import com.sargisgevorgyan.wordlegame.ui.WordleApp

class MainActivity : ComponentActivity() {
    private val app get() = application as WordleApplication
    private val playGames by lazy { PlayGamesService(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must precede super.onCreate: swaps the launch theme for Theme.WordleGame.
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Consent (UMP) before any ad request; shows the form only where required.
        if (savedInstanceState == null) app.ads.gatherConsent(this)
        setContent { WordleApp(playGames = playGames) }
    }

    override fun onResume() {
        super.onResume()
        // Restores purchases, finishes pending ones and notices a lapsed Pro subscription.
        app.billing.refresh()
    }
}
