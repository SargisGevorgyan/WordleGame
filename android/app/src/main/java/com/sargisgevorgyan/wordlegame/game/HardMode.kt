package com.sargisgevorgyan.wordlegame.game

/** Why a guess breaks Hard mode. [position] is 0-based. */
sealed interface HardModeViolation {
    data class MissingCorrect(val position: Int, val token: String) : HardModeViolation
    data class MissingPresent(val token: String) : HardModeViolation
}

/**
 * Hard mode: every revealed hint must be used in later guesses. A green letter
 * stays in its spot; a yellow letter (or green one) must appear somewhere, as
 * many times as it was revealed in a single row.
 */
object HardMode {
    fun violation(board: List<List<Tile>>, row: Int, guess: List<String>): HardModeViolation? {
        val revealed = board.take(row)
        for (tiles in revealed) tiles.forEachIndexed { i, tile ->
            val letter = tile.letter ?: return@forEachIndexed
            if (tile.evaluation == LetterEvaluation.CORRECT && guess.getOrNull(i) != letter) {
                return HardModeViolation.MissingCorrect(i, letter)
            }
        }
        for (tiles in revealed) {
            val required = tiles
                .filter { it.evaluation == LetterEvaluation.CORRECT || it.evaluation == LetterEvaluation.PRESENT }
                .mapNotNull { it.letter }
                .groupingBy { it }.eachCount()
            for ((token, count) in required) {
                if (guess.count { it == token } < count) return HardModeViolation.MissingPresent(token)
            }
        }
        return null
    }
}
