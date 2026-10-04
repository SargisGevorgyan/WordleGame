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
import com.sargisgevorgyan.wordlegame.game.DailyPuzzle
import com.sargisgevorgyan.wordlegame.game.GameLanguage
import com.sargisgevorgyan.wordlegame.game.GameMode
import com.sargisgevorgyan.wordlegame.game.GameRules
import com.sargisgevorgyan.wordlegame.game.GameState
import com.sargisgevorgyan.wordlegame.game.GameStatus
import com.sargisgevorgyan.wordlegame.game.ShareCard
import com.sargisgevorgyan.wordlegame.game.Stats
import com.sargisgevorgyan.wordlegame.game.Submission
import com.sargisgevorgyan.wordlegame.game.WordBank
import com.sargisgevorgyan.wordlegame.game.WordMeanings
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.launch

/** Drives the board, keyboard and game state; persists language, mode, daily progress, stats and hints. */
class GameViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = application.getSharedPreferences("wordle", Context.MODE_PRIVATE)
    private val banks = mutableMapOf<GameLanguage, WordBank>()
    private val meaningCache = mutableMapOf<GameLanguage, Map<String, String>>()

    var mode by mutableStateOf(GameMode.fromCode(prefs.getString(KEY_MODE, null)) ?: GameMode.DAILY)
        private set
    /** Day of the daily game on the board (see [DailyPuzzle.dayNumber]). */
    var dailyDay by mutableIntStateOf(DailyPuzzle.dayNumber())
        private set
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
    var hapticsEnabled by mutableStateOf(prefs.getBoolean(KEY_HAPTICS, true))
        private set
    var highContrast by mutableStateOf(prefs.getBoolean(KEY_HIGH_CONTRAST, false))
        private set

    /** Vibration cues for an invalid guess and the end of a game (key taps are handled by the keyboard). */
    enum class Feedback { INVALID, WIN, LOSS }

    private val _feedback = MutableSharedFlow<Feedback>(extraBufferCapacity = 4)
    val feedback: SharedFlow<Feedback> = _feedback

    /** Short meaning of the current target word (English gloss for Armenian), if known. */
    val meaning: String?
        get() = meanings(state.language)[state.targetWord.uppercase()]

    /** The free-play game set aside while the daily game is on screen. */
    private var freeGame: GameState? = null

    val puzzleNumber: Int? get() = if (mode == GameMode.DAILY) DailyPuzzle.puzzleNumber(dailyDay) else null
    val shareText: String get() = ShareCard.text(state, puzzleNumber)

    /** Whether switching language now would forfeit a free-play game (the daily one is saved). */
    val languageSwitchLosesGame: Boolean
        get() = (if (mode == GameMode.FREE) state else freeGame)?.isInProgress == true

    private var toastJob: Job? = null
    private var revealJob: Job? = null
    /** State to apply when the running reveal finishes. */
    private var pendingResolved: GameState? = null

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
        if (mode == GameMode.DAILY) return flashToast(R.string.hints_off_daily)
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
        pendingResolved = result.resolved
        revealJob = viewModelScope.launch {
            delay(REVEAL_MILLIS)
            completeReveal(result.resolved)
            if (state.status != GameStatus.PLAYING) {
                haptic(if (state.status == GameStatus.WON) Feedback.WIN else Feedback.LOSS)
                delay(450)
                showGameOver = true
            }
        }
    }

    private fun completeReveal(resolved: GameState) {
        state = resolved
        pendingResolved = null
        isRevealing = false
        revealingRow = -1
        if (mode == GameMode.DAILY) saveDaily(resolved)
        if (resolved.status != GameStatus.PLAYING) recordResult(won = resolved.status == GameStatus.WON)
    }

    private fun recordResult(won: Boolean) {
        stats = stats.record(won).also(::saveStats)
        if (won && hintsRemaining < FREE_HINT_CEILING) setHints(hintsRemaining + 1)
    }

    /** Stops any running reveal / game-over timer so it can't touch the next game. */
    private fun cancelReveal() {
        revealJob?.cancel()
        revealJob = null
        pendingResolved = null
        isRevealing = false
        revealingRow = -1
    }

    // New game / language

    /** "Play again" / dismissing the game-over dialog: a new free game, or back to the finished daily board. */
    fun newGame() {
        showGameOver = false
        if (mode == GameMode.DAILY) return
        cancelReveal()
        state = startGame(state.language)
    }

    /**
     * A free-play game in progress is abandoned and counts as a loss, so switching
     * can't protect a streak. Daily progress is saved per language and kept.
     */
    fun changeLanguage(language: GameLanguage) {
        if (language == state.language) return
        if (mode == GameMode.DAILY) {
            pendingResolved?.let { revealJob?.cancel(); completeReveal(it) }
            if (freeGame?.isInProgress == true) recordResult(won = false)
        } else {
            GameRules.abandonOutcome(state, pendingResolved)?.let { recordResult(won = it == GameStatus.WON) }
        }
        cancelReveal()
        freeGame = null
        prefs.edit { putString(KEY_LANGUAGE, language.code) }
        state = startGame(language)
        showGameOver = false
    }

    /** Switches between the daily word and free play; the free game waits while the daily is shown. */
    fun changeMode(newMode: GameMode) {
        if (newMode == mode || isRevealing) return
        val language = state.language
        if (newMode == GameMode.DAILY) freeGame = state
        mode = newMode
        prefs.edit { putString(KEY_MODE, newMode.code) }
        showGameOver = false
        state = freeGame?.takeIf { newMode == GameMode.FREE && it.status == GameStatus.PLAYING }
            ?: startGame(language)
        if (newMode == GameMode.FREE) freeGame = null
    }

    /** Loads the new day's word when the date has changed (app resumed, countdown ran out). */
    fun refreshDaily() {
        if (mode != GameMode.DAILY || isRevealing || DailyPuzzle.dayNumber() == dailyDay) return
        showGameOver = false
        state = startGame(state.language)
    }

    fun resetStats() {
        stats = Stats().also(::saveStats)
    }

    fun updateHaptics(enabled: Boolean) {
        hapticsEnabled = enabled
        prefs.edit { putBoolean(KEY_HAPTICS, enabled) }
    }

    fun updateHighContrast(enabled: Boolean) {
        highContrast = enabled
        prefs.edit { putBoolean(KEY_HIGH_CONTRAST, enabled) }
    }

    // Helpers

    private inline fun update(transform: (GameState) -> GameState) {
        if (!isRevealing) state = transform(state)
    }

    private fun invalid(@StringRes message: Int) {
        shakeToken++
        haptic(Feedback.INVALID)
        flashToast(message)
    }

    private fun haptic(feedback: Feedback) {
        if (hapticsEnabled) _feedback.tryEmit(feedback)
    }

    private fun flashToast(@StringRes message: Int) {
        toastJob?.cancel()
        toast = message
        toastJob = viewModelScope.launch {
            delay(1200)
            toast = null
        }
    }

    private fun startGame(language: GameLanguage): GameState {
        if (mode == GameMode.FREE) return GameRules.newGame(language, bank(language).randomWord())
        dailyDay = DailyPuzzle.dayNumber()
        val word = DailyPuzzle.word(bank(language), dailyDay)
        // Saved as "<day>|GUESS,GUESS"; another day's progress is ignored.
        val saved = prefs.getString(dailyKey(language), null)?.split('|', limit = 2)
        val guesses = saved?.takeIf { it.size == 2 && it[0] == dailyDay.toString() }
            ?.get(1)?.split(',')?.filter { it.isNotEmpty() }.orEmpty()
        return GameRules.replay(language, word, guesses, bank(language))
    }

    private fun saveDaily(state: GameState) = prefs.edit {
        putString(dailyKey(state.language), "$dailyDay|" + GameRules.guesses(state).joinToString(","))
    }

    private fun dailyKey(language: GameLanguage) = "daily.${language.code}"

    /** Loads `assets/words/words_<code>.txt` — packaged from the repo's shared/words. */
    private fun bank(language: GameLanguage): WordBank = banks.getOrPut(language) {
        val text = getApplication<Application>().assets
            .open("words/${language.wordFileName}").bufferedReader().use { it.readText() }
        WordBank(language, WordBank.parse(text))
    }

    /** Loads `assets/words/meanings_<code>.txt`; a missing file just means no meanings. */
    private fun meanings(language: GameLanguage): Map<String, String> = meaningCache.getOrPut(language) {
        runCatching {
            getApplication<Application>().assets
                .open("words/${language.meaningsFileName}").bufferedReader().use { WordMeanings.parse(it.readText()) }
        }.getOrDefault(emptyMap())
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
        private const val KEY_MODE = "gameMode"
        private const val KEY_HINTS = "hintsRemaining"
        private const val KEY_HAPTICS = "hapticsEnabled"
        private const val KEY_HIGH_CONTRAST = "highContrastColors"
        private const val KEY_PLAYED = "gamesPlayed"
        private const val KEY_WON = "gamesWon"
        private const val KEY_STREAK = "currentStreak"
        private const val KEY_MAX_STREAK = "maxStreak"
    }
}
