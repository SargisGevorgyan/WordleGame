package com.sargisgevorgyan.wordlegame

import android.app.Application
import com.sargisgevorgyan.wordlegame.games.PlayGamesService

class WordleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PlayGamesService.initialize(this)
    }
}
