package com.sargisgevorgyan.wordlegame.game

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Free play picks a random word; daily gives everyone the same word each day. */
enum class GameMode(val code: String) {
    DAILY("daily"),
    FREE("free");

    companion object {
        fun fromCode(code: String?): GameMode? = entries.firstOrNull { it.code == code }
    }
}

/**
 * The word of the day. Mirrors the iOS `DailyPuzzle` exactly, so players on both
 * apps get the same word on the same (local) date:
 *
 * - day = days from [EPOCH] to the player's local date; puzzle number = day + 1.
 * - The language's playable words are shuffled once with a fixed-seed SplitMix64
 *   Fisher–Yates, and day `d` plays entry `d mod count`. No word repeats until the
 *   whole list has been used.
 *
 * Editing a word list reshuffles the order, so ship word changes to both apps together.
 */
object DailyPuzzle {
    /** Day 0 (puzzle #1). */
    val EPOCH: LocalDate = LocalDate.of(2026, 10, 4)
    private const val SEED = 0x5752444C45UL // "WRDLE"

    fun dayNumber(date: LocalDate = LocalDate.now()): Int = ChronoUnit.DAYS.between(EPOCH, date).toInt()

    fun puzzleNumber(day: Int): Int = day + 1

    fun word(bank: WordBank, day: Int): String {
        val words = bank.playableWords
        return words[order(words.size)[Math.floorMod(day, words.size)]]
    }

    /**
     * The Armenian word of the day for learners: the same fixed order as the
     * daily puzzle, half the list away, so it never gives away today's (or a
     * nearby day's) daily answer.
     */
    fun learnerWord(bank: WordBank, day: Int): String = word(bank, day + bank.playableWords.size / 2)

    /** Fixed shuffle of `0 until count`. */
    fun order(count: Int): IntArray {
        val indices = IntArray(count) { it }
        val random = SplitMix64(SEED)
        for (i in count - 1 downTo 1) {
            val j = (random.next() % (i + 1).toULong()).toInt()
            indices[i] = indices[j].also { indices[j] = indices[i] }
        }
        return indices
    }

    internal class SplitMix64(private var state: ULong) {
        fun next(): ULong {
            state += 0x9E3779B97F4A7C15UL
            var z = state
            z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9UL
            z = (z xor (z shr 27)) * 0x94D049BB133111EBUL
            return z xor (z shr 31)
        }
    }
}

/** The emoji grid players paste into chats. */
object ShareCard {
    fun text(state: GameState, puzzleNumber: Int?): String {
        val rows = GameRules.submittedRows(state)
        val score = if (state.status == GameStatus.WON) rows.size.toString() else "X"
        val header = listOfNotNull(state.language.sampleTitle, puzzleNumber?.let { "#$it" }).joinToString(" ")
        val grid = rows.joinToString("\n") { row ->
            row.joinToString("") {
                when (it.evaluation) {
                    LetterEvaluation.CORRECT -> "🟩"
                    LetterEvaluation.PRESENT -> "🟨"
                    else -> "⬛"
                }
            }
        }
        return "$header $score/${GameRules.MAX_GUESSES}\n\n$grid"
    }
}
