package com.sargisgevorgyan.wordlegame.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class StatsRecordTest {

    private val phone = StatsRecord(Stats(10, 8, currentStreak = 0, maxStreak = 6), updatedAt = 200)
    private val tablet = StatsRecord(Stats(12, 7, currentStreak = 4, maxStreak = 5), updatedAt = 100)

    @Test fun mergeKeepsLargerCountsAndNewerCurrentStreak() {
        val merged = phone.merge(tablet)
        // Phone changed last: its loss broke the streak.
        assertEquals(StatsRecord(Stats(12, 8, currentStreak = 0, maxStreak = 6), updatedAt = 200), merged)
        assertEquals(merged, tablet.merge(phone))
    }

    @Test fun mergeDropsStatsOlderThanAReset() {
        val reset = StatsRecord(updatedAt = 300, resetAt = 300)
        val old = StatsRecord(Stats(50, 40, 9, 12), updatedAt = 250)
        assertEquals(reset, old.merge(reset))
        assertEquals(reset, reset.merge(old))
    }

    @Test fun gamesAfterAResetSurvive() {
        val reset = StatsRecord(updatedAt = 300, resetAt = 300)
        val after = reset.record(win = true, now = 400)
        assertEquals(after, reset.merge(after))
        assertEquals(Stats(1, 1, 1, 1), after.stats)
    }

    @Test fun mergingWithAnEmptyCloudKeepsLocal() =
        assertEquals(phone, phone.merge(StatsRecord()))

    @Test fun encodeRoundTrips() {
        val record = StatsRecord(Stats(12, 8, 3, 6), updatedAt = 1_700_000_000_000, resetAt = 5)
        assertEquals(record, StatsRecord.decode(record.encode()))
    }

    @Test fun decodeEmptyIsNull() {
        assertNull(StatsRecord.decode(""))
        assertNull(StatsRecord.decode("garbage"))
    }

    @Test fun achievementThresholds() {
        assertEquals(emptyList<Achievement>(), Achievement.earned(Stats()))
        assertEquals(
            listOf(Achievement.FIRST_WIN, Achievement.WINS_10, Achievement.STREAK_3),
            Achievement.earned(Stats(gamesPlayed = 20, gamesWon = 12, currentStreak = 0, maxStreak = 3)),
        )
    }
}
