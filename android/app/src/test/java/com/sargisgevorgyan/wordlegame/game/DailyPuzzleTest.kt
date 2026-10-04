package com.sargisgevorgyan.wordlegame.game

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.time.LocalDate

class DailyPuzzleTest {

    private val english = WordBank(GameLanguage.ENGLISH, listOf("CRANE", "PLANT", "SLATE"))

    // The iOS tests assert these same vectors, so both apps pick the same word.
    @Test fun splitMixMatchesReferenceVectors() {
        val random = DailyPuzzle.SplitMix64(0x5752444C45UL)
        assertEquals(0x92f8d4616f6e05f0UL, random.next())
        assertEquals(0x3fe1473bb8454ca4UL, random.next())
    }

    @Test fun orderMatchesReferenceShuffle() =
        assertArrayEquals(intArrayOf(3, 7, 1, 6, 8, 0, 9, 2, 5, 4), DailyPuzzle.order(10))

    @Test fun orderIsAPermutation() =
        assertEquals((0 until 457).toList(), DailyPuzzle.order(457).sorted())

    @Test fun dayNumberCountsFromEpoch() {
        assertEquals(0, DailyPuzzle.dayNumber(LocalDate.of(2026, 10, 4)))
        assertEquals(1, DailyPuzzle.puzzleNumber(DailyPuzzle.dayNumber(LocalDate.of(2026, 10, 4))))
        assertEquals(31, DailyPuzzle.dayNumber(LocalDate.of(2026, 11, 4)))
        assertEquals(-1, DailyPuzzle.dayNumber(LocalDate.of(2026, 10, 3)))
    }

    @Test fun wordIsStablePerDayAndCyclesThroughTheList() {
        val days = (0 until 3).map { DailyPuzzle.word(english, it) }
        assertEquals(english.playableWords.toSet(), days.toSet())
        assertEquals(DailyPuzzle.word(english, 1), DailyPuzzle.word(english, 4))
        assertEquals(DailyPuzzle.word(english, 2), DailyPuzzle.word(english, -1))
    }

    @Test fun sharedWordBankFirstDailyWords() {
        val dir = File(System.getProperty("sharedWordsDir") ?: "../../shared/words")
        val bank = WordBank(GameLanguage.ENGLISH, WordBank.parse(File(dir, "words_en.txt").readText()))
        (0 until 30).forEach { assertEquals(5, DailyPuzzle.word(bank, it).length) }
    }

    @Test fun replayRestoresBoardAndShareCard() {
        val state = GameRules.replay(GameLanguage.ENGLISH, "PLANT", listOf("CRANE", "SLATE", "PLANT"), english)
        assertEquals(GameStatus.WON, state.status)
        assertEquals(listOf("CRANE", "SLATE", "PLANT"), GameRules.guesses(state))
        assertEquals(
            "WORDY #7 3/6\n\n⬛⬛🟩🟩⬛\n⬛🟩🟩🟨⬛\n🟩🟩🟩🟩🟩",
            ShareCard.text(state, puzzleNumber = 7),
        )
    }

    @Test fun replayStopsAtWordsNoLongerInTheList() {
        val state = GameRules.replay(GameLanguage.ENGLISH, "PLANT", listOf("CRANE", "ZZZZZ", "SLATE"), english)
        assertEquals(listOf("CRANE"), GameRules.guesses(state))
        assertEquals(1, state.currentRow)
    }

    @Test fun lostGameSharesAnXWithoutNumberInFreePlay() {
        val guesses = List(6) { "CRANE" }
        val state = GameRules.replay(GameLanguage.ENGLISH, "PLANT", guesses, english)
        assertEquals(GameStatus.LOST, state.status)
        assertEquals("WORDY X/6", ShareCard.text(state, puzzleNumber = null).lineSequence().first())
    }
}
