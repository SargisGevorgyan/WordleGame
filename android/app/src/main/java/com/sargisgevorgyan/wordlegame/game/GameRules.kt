package com.sargisgevorgyan.wordlegame.game

/** The evaluation of one tile / key. */
enum class LetterEvaluation(val rank: Int) {
    EMPTY(0),    // no letter yet
    TBD(0),      // letter entered, not yet submitted
    CORRECT(3),  // right letter, right position  -> green
    PRESENT(2),  // right letter, wrong position  -> yellow
    ABSENT(1),   // letter not in the word        -> gray
}

/** One cell of the 6x5 board. [letter] is a token: one letter, or Armenian `"ՈՒ"`. */
data class Tile(val letter: String? = null, val evaluation: LetterEvaluation = LetterEvaluation.EMPTY)

enum class GameStatus { PLAYING, WON, LOST }

data class GameState(
    val language: GameLanguage,
    val targetWord: String,
    val board: List<List<Tile>> = GameRules.emptyBoard(),
    val currentRow: Int = 0,
    val currentColumn: Int = 0,
    val status: GameStatus = GameStatus.PLAYING,
    /** Keyed by board token. */
    val keyboardHints: Map<String, LetterEvaluation> = emptyMap(),
    /** Revealed hints must be used in later guesses. Fixed for the whole game. */
    val hardMode: Boolean = false,
    /** Played against the clock ([GameRules.TIME_LIMIT_SECONDS]). Fixed for the whole game. */
    val timed: Boolean = false,
    /** True when a timed game was lost because the clock ran out. */
    val timedOut: Boolean = false,
) {
    val currentTokens: List<String>
        get() = board.getOrNull(currentRow)?.mapNotNull { it.letter } ?: emptyList()

    /** True once the player has made progress that a language switch would discard. */
    val isInProgress: Boolean
        get() = status == GameStatus.PLAYING && (currentRow > 0 || currentTokens.isNotEmpty())
}

sealed interface Submission {
    data object NotEnoughLetters : Submission
    data object NotInWordList : Submission
    data class BreaksHardMode(val violation: HardModeViolation) : Submission
    /**
     * [revealed]: the row with its colours, for the flip animation.
     * [resolved]: the state after the reveal (hints merged, row advanced or game over).
     */
    data class Scored(val revealed: GameState, val resolved: GameState) : Submission
}

/** Pure game rules, shared by the view model and the unit tests. */
object GameRules {
    const val MAX_GUESSES = 6
    const val WORD_LENGTH = 5
    /** Timed mode: 3 minutes per game. */
    const val TIME_LIMIT_SECONDS = 180

    fun emptyBoard(): List<List<Tile>> = List(MAX_GUESSES) { List(WORD_LENGTH) { Tile() } }

    fun newGame(language: GameLanguage, targetWord: String, hardMode: Boolean = false, timed: Boolean = false) =
        GameState(language = language, targetWord = targetWord.uppercase(), hardMode = hardMode, timed = timed)

    /** Typed character (soft or hardware keyboard). */
    fun insert(state: GameState, character: Char): GameState {
        if (state.status != GameStatus.PLAYING) return state
        val letter = state.language.normalize(character) ?: return state

        // Armenian ու digraph: typing Ւ right after Ո merges them into one tile.
        val col = state.currentColumn
        if (state.language == GameLanguage.ARMENIAN && letter == 'Ւ' && col > 0) {
            val previous = state.board[state.currentRow][col - 1]
            if (previous.letter == "Ո" && previous.evaluation == LetterEvaluation.TBD) {
                return state.withTile(col - 1, previous.copy(letter = GameLanguage.DIGRAPH_OU))
            }
        }
        return insertToken(state, letter.toString())
    }

    /** Places a whole token in the next free tile. */
    fun insertToken(state: GameState, token: String): GameState {
        if (state.status != GameStatus.PLAYING || state.currentColumn >= WORD_LENGTH) return state
        return state.withTile(state.currentColumn, Tile(token.uppercase(), LetterEvaluation.TBD))
            .copy(currentColumn = state.currentColumn + 1)
    }

    /** On-screen key press: single letters go through [insert], tokens are placed as-is. */
    fun enterKey(state: GameState, token: String): GameState =
        if (token.length == 1) insert(state, token[0]) else insertToken(state, token)

    fun delete(state: GameState): GameState {
        if (state.status != GameStatus.PLAYING || state.currentColumn == 0) return state
        val col = state.currentColumn - 1
        return state.withTile(col, Tile()).copy(currentColumn = col)
    }

    /** The correct token for the next empty slot of the current row, or null. */
    fun hintToken(state: GameState): String? {
        if (state.status != GameStatus.PLAYING) return null
        return state.language.tokenize(state.targetWord).getOrNull(state.currentColumn)
            ?.takeIf { state.currentColumn < WORD_LENGTH }
    }

    fun submit(state: GameState, words: WordBank): Submission {
        if (state.currentColumn != WORD_LENGTH) return Submission.NotEnoughLetters
        val guessTokens = state.currentTokens
        val guess = guessTokens.joinToString("")
        if (!words.isValidGuess(guess)) return Submission.NotInWordList
        if (state.hardMode) {
            HardMode.violation(state.board, state.currentRow, guessTokens)?.let { return Submission.BreaksHardMode(it) }
        }

        val evaluations = evaluate(guessTokens, state.language.tokenize(state.targetWord))
        val row = state.board[state.currentRow].mapIndexed { i, tile ->
            tile.copy(evaluation = evaluations.getOrElse(i) { LetterEvaluation.ABSENT })
        }
        val revealed = state.copy(board = state.board.toMutableList().also { it[state.currentRow] = row })

        val hints = mergeHints(state.keyboardHints, guessTokens, evaluations)
        val resolved = when {
            guess == state.targetWord -> revealed.copy(status = GameStatus.WON, keyboardHints = hints)
            state.currentRow == MAX_GUESSES - 1 -> revealed.copy(status = GameStatus.LOST, keyboardHints = hints)
            else -> revealed.copy(currentRow = state.currentRow + 1, currentColumn = 0, keyboardHints = hints)
        }
        return Submission.Scored(revealed, resolved)
    }

    /**
     * What to record when a game is abandoned (language switch): the result of a
     * guess that was still revealing ([pendingResolved]) if it ended the game,
     * a loss if the game was in progress, or null if there's nothing to record.
     */
    fun abandonOutcome(state: GameState, pendingResolved: GameState?): GameStatus? = when {
        pendingResolved != null && pendingResolved.status != GameStatus.PLAYING -> pendingResolved.status
        (pendingResolved ?: state).isInProgress -> GameStatus.LOST
        else -> null
    }

    /**
     * The timed game's clock ran out. A guess still revealing ([pendingResolved])
     * decides it if it ended the game; otherwise the game is lost.
     */
    fun timeUp(state: GameState, pendingResolved: GameState?): GameState {
        val current = pendingResolved ?: state
        if (current.status != GameStatus.PLAYING) return current
        return current.copy(status = GameStatus.LOST, timedOut = true)
    }

    /** Rows that have been scored, top to bottom. */
    fun submittedRows(state: GameState): List<List<Tile>> = state.board.filter { row ->
        row.firstOrNull()?.evaluation.let { it != null && it != LetterEvaluation.EMPTY && it != LetterEvaluation.TBD }
    }

    /** The scored guesses, e.g. to save daily progress. */
    fun guesses(state: GameState): List<String> =
        submittedRows(state).map { row -> row.joinToString("") { it.letter.orEmpty() } }

    /** Rebuilds a game from saved [guesses]; stops at the first one that is no longer playable. */
    fun replay(language: GameLanguage, targetWord: String, guesses: List<String>, words: WordBank): GameState {
        var state = newGame(language, targetWord)
        for (guess in guesses) {
            if (state.status != GameStatus.PLAYING) break
            var typed = state
            language.tokenize(guess).forEach { typed = insertToken(typed, it) }
            state = (submit(typed, words) as? Submission.Scored)?.resolved ?: break
        }
        return state
    }

    /** Green beats yellow beats gray; a key is never downgraded. */
    fun mergeHints(
        current: Map<String, LetterEvaluation>,
        tokens: List<String>,
        evaluations: List<LetterEvaluation>,
    ): Map<String, LetterEvaluation> {
        val updated = current.toMutableMap()
        tokens.forEachIndexed { i, token ->
            val new = evaluations.getOrNull(i) ?: return@forEachIndexed
            if (new.rank > (updated[token]?.rank ?: 0)) updated[token] = new
        }
        return updated
    }

    /**
     * Classic two-pass Wordle scoring over tokens, with correct duplicate
     * handling (a token is one letter — Armenian "ՈՒ" included).
     */
    fun evaluate(guess: List<String>, target: List<String>): List<LetterEvaluation> {
        val n = minOf(guess.size, target.size)
        val result = MutableList(n) { LetterEvaluation.ABSENT }
        val remaining = target.groupingBy { it }.eachCount().toMutableMap()
        for (i in 0 until n) if (guess[i] == target[i]) {
            result[i] = LetterEvaluation.CORRECT
            remaining[guess[i]] = remaining.getValue(guess[i]) - 1
        }
        for (i in 0 until n) if (result[i] != LetterEvaluation.CORRECT) {
            val count = remaining[guess[i]] ?: 0
            if (count > 0) {
                result[i] = LetterEvaluation.PRESENT
                remaining[guess[i]] = count - 1
            }
        }
        return result
    }

    /** Character-level convenience (English / tests). */
    fun evaluate(guess: String, target: String): List<LetterEvaluation> =
        evaluate(guess.uppercase().map(Char::toString), target.uppercase().map(Char::toString))

    private fun GameState.withTile(column: Int, tile: Tile): GameState {
        val row = board[currentRow].toMutableList().also { it[column] = tile }
        return copy(board = board.toMutableList().also { it[currentRow] = row })
    }
}
