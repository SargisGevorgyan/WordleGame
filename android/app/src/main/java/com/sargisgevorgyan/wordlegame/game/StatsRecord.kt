package com.sargisgevorgyan.wordlegame.game

/**
 * [Stats] plus the timestamps (epoch millis) needed to merge two devices' copies.
 * Same rules as the iOS app's `StatsSnapshot`.
 */
data class StatsRecord(
    val stats: Stats = Stats(),
    /** Last local change. */
    val updatedAt: Long = 0,
    /** Last "Reset Statistics"; copies changed before it are stale. */
    val resetAt: Long = 0,
) {
    fun record(win: Boolean, now: Long) = copy(stats = stats.record(win), updatedAt = now)

    /**
     * Counts and best streak take the larger value; the current streak comes from
     * whichever copy changed last. A copy last changed before the newest reset is
     * dropped, so a reset isn't undone by another device.
     */
    fun merge(other: StatsRecord): StatsRecord {
        val reset = maxOf(resetAt, other.resetAt)
        val live = listOf(this, other).filter { it.updatedAt >= reset }
        val newer = live.maxByOrNull { it.updatedAt } ?: return StatsRecord(updatedAt = reset, resetAt = reset)
        if (live.size == 1) return newer.copy(resetAt = reset)
        val a = stats
        val b = other.stats
        val played = maxOf(a.gamesPlayed, b.gamesPlayed)
        return StatsRecord(
            stats = Stats(
                gamesPlayed = played,
                gamesWon = minOf(maxOf(a.gamesWon, b.gamesWon), played),
                currentStreak = newer.stats.currentStreak,
                maxStreak = maxOf(a.maxStreak, b.maxStreak, newer.stats.currentStreak),
            ),
            updatedAt = newer.updatedAt,
            resetAt = reset,
        )
    }

    /** Plain `key=value` lines, so the cloud file is readable and forward compatible. */
    fun encode(): String = listOf(
        "version" to 1,
        KEY_PLAYED to stats.gamesPlayed,
        KEY_WON to stats.gamesWon,
        KEY_STREAK to stats.currentStreak,
        KEY_MAX_STREAK to stats.maxStreak,
        KEY_UPDATED to updatedAt,
        KEY_RESET to resetAt,
    ).joinToString("\n") { (key, value) -> "$key=$value" }

    companion object {
        private const val KEY_PLAYED = "gamesPlayed"
        private const val KEY_WON = "gamesWon"
        private const val KEY_STREAK = "currentStreak"
        private const val KEY_MAX_STREAK = "maxStreak"
        private const val KEY_UPDATED = "updatedAt"
        private const val KEY_RESET = "resetAt"

        /** Null for an empty or unreadable file (e.g. a brand-new cloud save). */
        fun decode(text: String): StatsRecord? {
            val values = text.lineSequence()
                .mapNotNull { line -> line.split('=', limit = 2).takeIf { it.size == 2 } }
                .associate { (key, value) -> key.trim() to value.trim().toLongOrNull() }
            if (values.isEmpty()) return null
            fun int(key: String) = (values[key] ?: 0L).toInt().coerceAtLeast(0)
            return StatsRecord(
                stats = Stats(int(KEY_PLAYED), int(KEY_WON), int(KEY_STREAK), int(KEY_MAX_STREAK)),
                updatedAt = values[KEY_UPDATED] ?: 0,
                resetAt = values[KEY_RESET] ?: 0,
            )
        }
    }
}

/** Milestones unlocked from stats; mirrors iOS `GameCenterManager.Achievement`. */
enum class Achievement(private val minWins: Int = 0, private val minBestStreak: Int = 0) {
    FIRST_WIN(minWins = 1),
    WINS_10(minWins = 10),
    WINS_100(minWins = 100),
    STREAK_3(minBestStreak = 3),
    STREAK_7(minBestStreak = 7),
    STREAK_30(minBestStreak = 30);

    fun isEarned(stats: Stats) = stats.gamesWon >= minWins && stats.maxStreak >= minBestStreak

    companion object {
        fun earned(stats: Stats) = entries.filter { it.isEarned(stats) }
    }
}
