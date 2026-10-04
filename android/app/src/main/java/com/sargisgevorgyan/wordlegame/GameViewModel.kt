package com.sargisgevorgyan.wordlegame

import android.app.Application
import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.sargisgevorgyan.wordlegame.game.GameLanguage
import com.sargisgevorgyan.wordlegame.game.GameRules
import com.sargisgevorgyan.wordlegame.game.GameState
import com.sargisgevorgyan.wordlegame.game.GameStatus
import com.sargisgevorgyan.wordlegame.game.Stats
import com.sargisgevorgyan.wordlegame.game.Submission
import com.sargisgevorgyan.wordlegame.game.WordBank
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Drives the board, keyboard and game state; persists language, stats and hints. */
class GameViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = application.getSharedPreferences("wordle", Context.MODE_PRIVATE)
    private val banks = mutableMapOf<GameLanguage, WordBank>()

    var state by mutableStateOf(startGame(storedLanguage()))
        private set
    var isRevealing by mutableStateOf(false)
        private set
    /** Row currently flipping (for the staggered reveal animation), or -1. */
    var revealingRow by mutableIntStateOf(-1)
        private set
    /** Bumped to make the active row shake. */
    var shakeToken by mutableIntStateOf(0)
        private set
    var toast by mutableStateOf<Int?>(null)
        private set
    var showGameOver by mutableStateOf(false)
    var stats by mutableStateOf(loadStats())
        private set
    var hintsRemaining by mutableIntStateOf(prefs.getInt(KEY_HINTS, 3))
        private set

    private var toastJob: Job? = null

    // Input

    fun onKey(token: String) = when (token) {
        GameLanguage.KEY_ENTER -> submit()
        GameLanguage.KEY_DELETE -> delete()
        else -> update { GameRules.enterKey(it, token) }
    }

    fun onTypedChar(char: Char) = update { GameRules.insert(it, char) }

    fun delete() = update(GameRules::delete)

    fun useHint() {
        if (isRevealing || state.status != GameStatus.PLAYING) return
        if (hintsRemaining <= 0) return flashToast(R.string.no_hints_left)
        val token = GameRules.hintToken(state) ?: return
        setHints(hintsRemaining - 1)
        state = GameRules.insertToken(state, token)
        flashToast(R.string.hint_revealed)
    }

    fun submit() {
        if (isRevealing || state.status != GameStatus.PLAYING) return
        when (val result = GameRules.submit(state, bank(state.language))) {
            Submission.NotEnoughLetters -> invalid(R.string.not_enough_letters)
            Submission.NotInWordList -> invalid(R.string.not_in_word_list)
            is Submission.Scored -> reveal(result)
        }
    }

    private fun reveal(result: Submission.Scored) {
        isRevealing = true
        revealingRow = state.currentRow
        state = result.revealed
        viewModelScope.launch {
            delay(REVEAL_MILLIS)
            state = result.resolved
            isRevealing = false
            revealingRow = -1
            if (state.status != GameStatus.PLAYING) finishGame(won = state.status == GameStatus.WON)
        }
    }

    private suspend fun finishGame(won: Boolean) {
        stats = stats.record(won).also(::saveStats)
        if (won && hintsRemaining < FREE_HINT_CEILING) setHints(hintsRemaining + 1)
        delay(450)
        showGameOver = true
    }

    // New game / language

    fun newGame() {
        showGameOver = false
        state = startGame(state.language)
    }

    fun changeLanguage(language: GameLanguage) {
        if (language == state.language) return
        prefs.edit { putString(KEY_LANGUAGE, language.code) }
        state = startGame(language)
        showGameOver = false
    }

    fun resetStats() {
        stats = Stats().also(::saveStats)
    }

    // Helpers

    private inline fun update(transform: (GameState) -> GameState) {
        if (!isRevealing) state = transform(state)
    }

    private fun invalid(@StringRes message: Int) {
        shakeToken++
        flashToast(message)
    }

    private fun flashToast(@StringRes message: Int) {
        toastJob?.cancel()
        toast = message
        toastJob = viewModelScope.launch {
            delay(1200)
            toast = null
        }
    }

    private fun startGame(language: GameLanguage) =
        GameRules.newGame(language, bank(language).randomWord())

    /** Loads `assets/words/words_<code>.txt` — packaged from the repo's shared/words. */
    private fun bank(language: GameLanguage): WordBank = banks.getOrPut(language) {
        val text = getApplication<Application>().assets
            .open("words/${language.wordFileName}").bufferedReader().use { it.readText() }
        WordBank(language, WordBank.parse(text))
    }

    private fun storedLanguage() =
        GameLanguage.fromCode(prefs.getString(KEY_LANGUAGE, null)) ?: GameLanguage.systemDefault()

    private fun setHints(value: Int) {
        hintsRemaining = value.coerceIn(0, MAX_HINTS)
        prefs.edit { putInt(KEY_HINTS, hintsRemaining) }
    }

    private fun loadStats() = Stats(
        gamesPlayed = prefs.getInt(KEY_PLAYED, 0),
        gamesWon = prefs.getInt(KEY_WON, 0),
        currentStreak = prefs.getInt(KEY_STREAK, 0),
        maxStreak = prefs.getInt(KEY_MAX_STREAK, 0),
    )

    private fun saveStats(stats: Stats) = prefs.edit {
        putInt(KEY_PLAYED, stats.gamesPlayed)
        putInt(KEY_WON, stats.gamesWon)
        putInt(KEY_STREAK, stats.currentStreak)
        putInt(KEY_MAX_STREAK, stats.maxStreak)
    }

    companion object {
        const val REVEAL_MILLIS = 1700L
        const val FLIP_STAGGER_MILLIS = 300
        private const val MAX_HINTS = 99
        private const val FREE_HINT_CEILING = 5
        private const val KEY_LANGUAGE = "gameLanguage"
        private const val KEY_HINTS = "hintsRemaining"
        private const val KEY_PLAYED = "gamesPlayed"
        private const val KEY_WON = "gamesWon"
        private const val KEY_STREAK = "currentStreak"
        private const val KEY_MAX_STREAK = "maxStreak"
    }
}
