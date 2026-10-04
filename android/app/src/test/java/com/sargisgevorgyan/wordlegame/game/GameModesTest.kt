package com.sargisgevorgyan.wordlegame.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class GameModesTest {

    private val english = WordBank(GameLanguage.ENGLISH, listOf("CRANE", "PLANT", "SLATE", "TRACE", "CRATE", "BUMPY"))

    private fun type(state: GameState, text: String) = text.fold(state, GameRules::insert)

    private fun play(state: GameState, guess: String) =
        GameRules.submit(type(state, guess), english)

    // Hard mode

    @Test fun hardModeRequiresGreensInPlace() {
        // PLANT vs CRANE: A and N green.
        val afterPlant = (play(GameRules.newGame(GameLanguage.ENGLISH, "CRANE", hardMode = true), "PLANT") as Submission.Scored).resolved
        val result = play(afterPlant, "SLATE")
        assertEquals(Submission.BreaksHardMode(HardModeViolation.MissingCorrect(3, "N")), result)
    }

    @Test fun hardModeRequiresYellowsSomewhere() {
        // TRACE vs CRATE: T and C yellow, R A E green.
        val afterTrace = (play(GameRules.newGame(GameLanguage.ENGLISH, "CRATE", hardMode = true), "TRACE") as Submission.Scored).resolved
        // CRANE keeps R A _ _ E and has C but no T.
        assertEquals(Submission.BreaksHardMode(HardModeViolation.MissingPresent("T")), play(afterTrace, "CRANE"))
        assertTrue(play(afterTrace, "CRATE") is Submission.Scored)
    }

    @Test fun hardModeOffAllowsAnyValidGuess() {
        val afterPlant = (play(GameRules.newGame(GameLanguage.ENGLISH, "CRANE"), "PLANT") as Submission.Scored).resolved
        assertTrue(play(afterPlant, "BUMPY") is Submission.Scored)
    }

    @Test fun hardModeCountsRepeatedRevealedLetters() {
        val board = GameRules.emptyBoard().toMutableList()
        board[0] = listOf("E", "E", "R", "I", "E").mapIndexed { i, t ->
            Tile(t, if (i < 2) LetterEvaluation.PRESENT else LetterEvaluation.ABSENT)
        }
        assertEquals(HardModeViolation.MissingPresent("E"), HardMode.violation(board, 1, listOf("C", "R", "A", "N", "E")))
        assertNull(HardMode.violation(board, 1, listOf("E", "X", "E", "R", "T")))
    }

    // Timed mode

    @Test fun timeUpLosesAGameInProgress() {
        val state = type(GameRules.newGame(GameLanguage.ENGLISH, "CRANE", timed = true), "PL")
        val ended = GameRules.timeUp(state, null)
        assertEquals(GameStatus.LOST, ended.status)
        assertTrue(ended.timedOut)
    }

    @Test fun timeUpLetsARevealingWinCount() {
        val start = GameRules.newGame(GameLanguage.ENGLISH, "CRANE", timed = true)
        val winning = play(start, "CRANE") as Submission.Scored
        val ended = GameRules.timeUp(winning.revealed, winning.resolved)
        assertEquals(GameStatus.WON, ended.status)
        assertFalse(ended.timedOut)
        val wrong = play(start, "PLANT") as Submission.Scored
        assertEquals(GameStatus.LOST, GameRules.timeUp(wrong.revealed, wrong.resolved).status)
    }

    @Test fun modesCarryIntoTheGame() {
        val state = GameRules.newGame(GameLanguage.ENGLISH, "crane", hardMode = true, timed = true)
        assertTrue(state.hardMode && state.timed && !state.timedOut)
    }

    // Glossary

    private val sharedDir = File(System.getProperty("sharedWordsDir") ?: "../../shared/words")

    @Test fun glossaryParsesTabSeparatedLines() {
        val glossary = Glossary.parse("# c\n\nԳԱՐՈՒՆ\tspring (season)\nBAD LINE\nՔԱՂԱՔ\t \n")
        assertEquals(listOf("ԳԱՐՈՒՆ" to "spring (season)"), glossary.entries)
        assertEquals("spring (season)", glossary.meaning("գարուն"))
        assertNull(glossary.meaning("ՔԱՂԱՔ"))
    }

    @Test fun wordOfTheDayIsStableAndPlayable() {
        val bank = WordBank(GameLanguage.ARMENIAN, listOf("ԳԱՐՈՒՆ", "ՔԱՂԱՔ", "ԱՇՈՒՆ"))
        val glossary = Glossary.parse("ԱՇՈՒՆ\tautumn\nԳԱՐՈՒՆ\tspring\nՔԱՂԱՔ\tcity\n")
        val day = glossary.wordOfTheDay(20_000, bank)!!
        assertEquals(day, glossary.wordOfTheDay(20_000, bank))
        assertTrue(day.first != "ԱՇՈՒՆ")                       // 4 board letters: not playable
        assertEquals(0, Glossary.dayIndex(0, 7))
        assertEquals(Math.floorMod(-7919L, 7L).toInt(), Glossary.dayIndex(-1, 7))
    }

    @Test fun sharedArmenianGlossesMatchTheWordBank() {
        val words = WordBank.parse(File(sharedDir, GameLanguage.ARMENIAN.wordFileName).readText()).toSet()
        val glossary = Glossary.parse(File(sharedDir, GameLanguage.ARMENIAN.glossFileName).readText())
        assertTrue(glossary.entries.size >= 400)
        glossary.entries.forEach { (word, _) -> assertTrue("$word is glossed but not in the word bank", word in words) }
        assertEquals(glossary.entries.size, glossary.entries.map { it.first }.toSet().size)
    }
}
