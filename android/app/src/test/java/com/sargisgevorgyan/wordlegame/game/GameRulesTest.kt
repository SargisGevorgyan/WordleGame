package com.sargisgevorgyan.wordlegame.game

import com.sargisgevorgyan.wordlegame.game.LetterEvaluation.ABSENT
import com.sargisgevorgyan.wordlegame.game.LetterEvaluation.CORRECT
import com.sargisgevorgyan.wordlegame.game.LetterEvaluation.PRESENT
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class GameRulesTest {

    private val english = WordBank(GameLanguage.ENGLISH, listOf("CRANE", "PLANT", "SLATE", "SILK"))
    private val armenian = WordBank(GameLanguage.ARMENIAN, listOf("ՔԱՂԱՔ", "ԳԱՐՈՒՆ", "ԱՇՈՒՆ", "ԿԱՆՈՆ"))

    private fun type(state: GameState, text: String) = text.fold(state, GameRules::insert)

    // Scoring

    @Test fun exactMatchIsAllCorrect() =
        assertEquals(List(5) { CORRECT }, GameRules.evaluate("CRANE", "CRANE"))

    @Test fun absentLetters() =
        assertEquals(List(5) { ABSENT }, GameRules.evaluate("BUMPY", "CRANE"))

    @Test fun duplicateHandlingGreensFirst() {
        // Target CRANE has one E; EERIE's last E is green, other Es grey.
        assertEquals(listOf(ABSENT, ABSENT, PRESENT, ABSENT, CORRECT), GameRules.evaluate("EERIE", "CRANE"))
    }

    @Test fun presentButWrongPosition() =
        assertEquals(listOf(PRESENT, PRESENT, PRESENT, PRESENT, PRESENT), GameRules.evaluate("NACER", "CRANE"))

    @Test fun evaluationIsCaseInsensitive() =
        assertEquals(GameRules.evaluate("CRANE", "CRANE"), GameRules.evaluate("crane", "Crane"))

    @Test fun armenianDigraphIsScoredAsOneLetter() {
        val lang = GameLanguage.ARMENIAN
        assertEquals(listOf("Գ", "Ա", "Ր", "ՈՒ", "Ն"), lang.tokenize("ԳԱՐՈՒՆ"))
        assertEquals(List(5) { CORRECT }, GameRules.evaluate(lang.tokenize("ԳԱՐՈՒՆ"), lang.tokenize("ԳԱՐՈՒՆ")))
        // Ո alone is not ՈՒ.
        assertEquals(ABSENT, GameRules.evaluate(lang.tokenize("ԿԱՆՈՆ"), lang.tokenize("ԳԱՐՈՒՆ"))[3])
    }

    // Flow

    @Test fun winningFlowUpdatesStatus() {
        var state = type(GameRules.newGame(GameLanguage.ENGLISH, "CRANE"), "crane")
        val result = GameRules.submit(state, english) as Submission.Scored
        state = result.resolved
        assertEquals(GameStatus.WON, state.status)
        assertEquals(List(5) { CORRECT }, result.revealed.board[0].map { it.evaluation })
    }

    @Test fun losingAfterSixGuesses() {
        var state = GameRules.newGame(GameLanguage.ENGLISH, "CRANE")
        repeat(GameRules.MAX_GUESSES) {
            state = (GameRules.submit(type(state, "PLANT"), english) as Submission.Scored).resolved
        }
        assertEquals(GameStatus.LOST, state.status)
    }

    @Test fun wrongGuessAdvancesRowAndMergesHints() {
        val state = (GameRules.submit(type(GameRules.newGame(GameLanguage.ENGLISH, "CRANE"), "PLANT"), english)
            as Submission.Scored).resolved
        assertEquals(1, state.currentRow)
        assertEquals(0, state.currentColumn)
        assertEquals(CORRECT, state.keyboardHints["A"])
        assertEquals(CORRECT, state.keyboardHints["N"])
        assertEquals(ABSENT, state.keyboardHints["P"])
    }

    @Test fun invalidWordAndShortWordAreRejected() {
        val start = GameRules.newGame(GameLanguage.ENGLISH, "CRANE")
        assertSame(Submission.NotInWordList, GameRules.submit(type(start, "ZZZZZ"), english))
        assertSame(Submission.NotEnoughLetters, GameRules.submit(type(start, "CRA"), english))
    }

    @Test fun armenianDigraphMergeWhileTyping() {
        val state = type(GameRules.newGame(GameLanguage.ARMENIAN, "ԳԱՐՈՒՆ"), "գարուն")
        assertEquals(listOf("Գ", "Ա", "Ր", "ՈՒ", "Ն"), state.currentTokens)
        assertEquals(GameStatus.WON, (GameRules.submit(state, armenian) as Submission.Scored).resolved.status)
    }

    @Test fun deleteRemovesWholeDigraphTile() {
        var state = type(GameRules.newGame(GameLanguage.ARMENIAN, "ԳԱՐՈՒՆ"), "ԳԱՐՈՒ")
        state = GameRules.delete(state)
        assertEquals(listOf("Գ", "Ա", "Ր"), state.currentTokens)
    }

    @Test fun nonAlphabetInputIsIgnored() {
        val start = GameRules.newGame(GameLanguage.ENGLISH, "CRANE")
        assertEquals(start, type(start, "1é!Ա"))
        // և uppercases to two letters → no-op instead of a crash.
        val hy = GameRules.newGame(GameLanguage.ARMENIAN, "ՔԱՂԱՔ")
        assertEquals(hy, GameRules.insert(hy, 'և'))
    }

    @Test fun keyboardHintsNeverDowngrade() {
        val merged = GameRules.mergeHints(mapOf("A" to CORRECT), listOf("A", "B"), listOf(ABSENT, PRESENT))
        assertEquals(CORRECT, merged["A"])
        assertEquals(PRESENT, merged["B"])
    }

    @Test fun hintGivesNextTargetToken() {
        var state = type(GameRules.newGame(GameLanguage.ARMENIAN, "ԳԱՐՈՒՆ"), "ԳԱՐ")
        assertEquals("ՈՒ", GameRules.hintToken(state))
        state = GameRules.insertToken(state, "ՈՒ")
        state = GameRules.insertToken(state, "Ն")
        assertNull(GameRules.hintToken(state))
    }

    @Test fun languageDefaultFollowsLocale() {
        assertEquals(GameLanguage.ARMENIAN, GameLanguage.systemDefault(Locale("hy")))
        assertEquals(GameLanguage.ARMENIAN, GameLanguage.systemDefault(Locale("ru", "AM")))
        assertEquals(GameLanguage.ENGLISH, GameLanguage.systemDefault(Locale.US))
    }

    @Test fun winPercentage() {
        assertEquals(0, Stats.winPercentage(0, 0))
        assertEquals(25, Stats.winPercentage(4, 1))
        assertEquals(67, Stats.winPercentage(3, 2))
        val stats = Stats().record(true).record(true).record(false).record(true)
        assertEquals(Stats(gamesPlayed = 4, gamesWon = 3, currentStreak = 1, maxStreak = 2), stats)
    }

    @Test fun wrongLengthWordsAreNotPlayable() {
        assertFalse(english.isValidGuess("SILK"))
        assertTrue(armenian.isValidGuess("ԳԱՐՈՒՆ"))   // Գ Ա Ր ՈՒ Ն → 5 letters
        assertFalse(armenian.isValidGuess("ԱՇՈՒՆ"))   // Ա Շ ՈՒ Ն → only 4
    }
}
