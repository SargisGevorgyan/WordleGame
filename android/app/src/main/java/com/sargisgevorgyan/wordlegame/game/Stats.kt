package com.sargisgevorgyan.wordlegame.game

data class Stats(
    val gamesPlayed: Int = 0,
    val gamesWon: Int = 0,
    val currentStreak: Int = 0,
    val maxStreak: Int = 0,
) {
    val winPercentage: Int get() = winPercentage(gamesPlayed, gamesWon)

    fun record(win: Boolean): Stats = if (win) {
        val streak = currentStreak + 1
        copy(gamesPlayed = gamesPlayed + 1, gamesWon = gamesWon + 1,
            currentStreak = streak, maxStreak = maxOf(streak, maxStreak))
    } else {
        copy(gamesPlayed = gamesPlayed + 1, currentStreak = 0)
    }

    companion object {
        fun winPercentage(played: Int, won: Int): Int =
            if (played <= 0) 0 else Math.round(won.toDouble() / played * 100).toInt()
    }
}
