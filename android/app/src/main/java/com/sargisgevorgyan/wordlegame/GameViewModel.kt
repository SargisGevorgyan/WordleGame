package com.sargisgevorgyan.wordlegame

import android.app.Application
import android.content.Context
import android.os.SystemClock
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
import com.sargisgevorgyan.wordlegame.game.Glossary
import com.sargisgevorgyan.wordlegame.game.HardModeViolation
import com.sargisgevorgyan.wordlegame.game.Stats
import com.sargisgevorgyan.wordlegame.game.Submission
import com.sargisgevorgyan.wordlegame.game.WordBank
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate

/** A toast: a string resource plus its format arguments. */
data class UiMessage(@StringRes val res: Int, val args: List<Any> = emptyList())

/** Drives the board, keyboard and game state; persists language, modes, stats and hints. */
class GameViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = application.getSharedPreferences("wordle", Context.MODE_PRIVATE)
    private val banks = mutableMapOf<GameLanguage, WordBank>()

    /** Settings; a change applies now if the game hasn't started, otherwise from the next game. */
    var hardMode by mutableStateOf(prefs.getBoolean(KEY_HARD_MODE, false))
        private set
    var timedMode by mutableStateOf(prefs.getBoolean(KEY_TIMED_MODE, false))
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
    var toast by mutableStateOf<UiMessage?>(null)
        private set
    var showGameOver by mutableStateOf(false)
    var stats by mutableStateOf(loadStats())
        private set
    var hintsRemaining by mutableIntStateOf(prefs.getInt(KEY_HINTS, 3))
        private set

    /** Timed mode: seconds left. The clock starts with the first letter. */
    var secondsLeft by mutableIntStateOf(GameRules.TIME_LIMIT_SECONDS)
        private set

    private var toastJob: Job? = null
    private var revealJob: Job? = null
    private var timerJob: Job? = null
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
        if (hintsRemaining <= 0) return flashToast(R.string.no_hints_left)
        val token = GameRules.hintToken(state) ?: return
        setHints(hintsRemaining - 1)
        state = GameRules.insertToken(state, token)
        startClockIfNeeded()
        flashToast(R.string.hint_revealed)
    }

    fun submit() {
        if (isRevealing || state.status != GameStatus.PLAYING) return
        when (val result = GameRules.submit(state, bank(state.language))) {
            Submission.NotEnoughLetters -> invalid(R.string.not_enough_letters)
            Submission.NotInWordList -> invalid(R.string.not_in_word_list)
            is Submission.BreaksHardMode -> invalid(hardModeMessage(result.violation))
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
            state = result.resolved
            pendingResolved = null
            isRevealing = false
            revealingRow = -1
            if (state.status != GameStatus.PLAYING) {
                stopClock()
                recordResult(won = state.status == GameStatus.WON)
                delay(450)
                showGameOver = true
            }
        }
    }

    // Timed mode

    private fun startClockIfNeeded() {
        if (!state.timed || timerJob != null || state.status != GameStatus.PLAYING || !state.isInProgress) return
        val deadline = SystemClock.elapsedRealtime() + GameRules.TIME_LIMIT_SECONDS * 1000L
        timerJob = viewModelScope.launch {
            while (true) {
                val left = deadline - SystemClock.elapsedRealtime()
                secondsLeft = ((left + 999) / 1000).toInt().coerceAtLeast(0)
                if (left <= 0) break
                delay(minOf(left, 250L))
            }
            timerJob = null
            timeUp()
        }
    }

    private fun stopClock() {
        timerJob?.cancel()
        timerJob = null
    }

    private fun timeUp() {
        val pending = pendingResolved
        revealJob?.cancel()
        revealJob = null
        pendingResolved = null
        isRevealing = false
        revealingRow = -1
        state = GameRules.timeUp(state, pending)
        recordResult(won = state.status == GameStatus.WON)
        revealJob = viewModelScope.launch {
            delay(450)
            showGameOver = true
        }
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

    fun newGame() {
        cancelReveal()
        stopClock()
        secondsLeft = GameRules.TIME_LIMIT_SECONDS
        showGameOver = false
        state = startGame(state.language)
    }

    /** The game in progress is abandoned and counts as a loss, so switching can't protect a streak. */
    fun changeLanguage(language: GameLanguage) {
        if (language == state.language) return
        GameRules.abandonOutcome(state, pendingResolved)?.let { recordResult(won = it == GameStatus.WON) }
        cancelReveal()
        stopClock()
        secondsLeft = GameRules.TIME_LIMIT_SECONDS
        prefs.edit { putString(KEY_LANGUAGE, language.code) }
        state = startGame(language)
        showGameOver = false
    }

    fun changeHardMode(enabled: Boolean) {
        hardMode = enabled
        prefs.edit { putBoolean(KEY_HARD_MODE, enabled) }
        if (!state.isInProgress && state.status == GameStatus.PLAYING) state = state.copy(hardMode = enabled)
    }

    fun changeTimedMode(enabled: Boolean) {
        timedMode = enabled
        prefs.edit { putBoolean(KEY_TIMED_MODE, enabled) }
        if (!state.isInProgress && state.status == GameStatus.PLAYING) {
            state = state.copy(timed = enabled)
            secondsLeft = GameRules.TIME_LIMIT_SECONDS
        }
    }

    // Meanings

    /** English meaning of the finished game's word, when the shared glossary has one. */
    val targetMeaning: String?
        get() = glossary(state.language)?.meaning(state.targetWord)

    /** Today's Armenian word and its English meaning, for learners. */
    val armenianWordOfTheDay: Pair<String, String>?
        get() = glossary(GameLanguage.ARMENIAN)?.wordOfTheDay(LocalDate.now().toEpochDay(), bank(GameLanguage.ARMENIAN))

    private val glossaries = mutableMapOf<GameLanguage, Glossary?>()

    /** Loads `assets/words/glosses_<code>.tsv` (from the repo's shared/words), or null if there is none. */
    private fun glossary(language: GameLanguage): Glossary? = glossaries.getOrPut(language) {
        runCatching {
            getApplication<Application>().assets.open("words/${language.glossFileName}")
                .bufferedReader().use { Glossary.parse(it.readText()) }
        }.getOrNull()
    }

    fun resetStats() {
        stats = Stats().also(::saveStats)
    }

    // Helpers

    private inline fun update(transform: (GameState) -> GameState) {
        if (isRevealing) return
        state = transform(state)
        startClockIfNeeded()
    }

    private fun invalid(@StringRes message: Int) = invalid(UiMessage(message))

    private fun invalid(message: UiMessage) {
        shakeToken++
        flashToast(message)
    }

    private fun hardModeMessage(violation: HardModeViolation) = when (violation) {
        is HardModeViolation.MissingCorrect -> UiMessage(R.string.hard_mode_position, listOf(violation.position + 1, violation.token))
        is HardModeViolation.MissingPresent -> UiMessage(R.string.hard_mode_contain, listOf(violation.token))
    }

    private fun flashToast(@StringRes message: Int) = flashToast(UiMessage(message))

    private fun flashToast(message: UiMessage) {
        toastJob?.cancel()
        toast = message
        toastJob = viewModelScope.launch {
            delay(1200)
            toast = null
        }
    }

    private fun startGame(language: GameLanguage) = GameRules.newGame(
        language,
        bank(language).randomWord(),
        hardMode = prefs.getBoolean(KEY_HARD_MODE, false),
        timed = prefs.getBoolean(KEY_TIMED_MODE, false),
    )

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
        private const val KEY_HARD_MODE = "hardMode"
        private const val KEY_TIMED_MODE = "timedMode"
        private const val KEY_HINTS = "hintsRemaining"
        private const val KEY_PLAYED = "gamesPlayed"
        private const val KEY_WON = "gamesWon"
        private const val KEY_STREAK = "currentStreak"
        private const val KEY_MAX_STREAK = "maxStreak"
    }
}
