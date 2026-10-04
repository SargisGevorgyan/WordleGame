package com.sargisgevorgyan.wordlegame.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Checks the shared word bank (`shared/words`, also bundled by the iOS app). */
class SharedWordBankTest {

    private val dir = File(System.getProperty("sharedWordsDir") ?: "../../shared/words")

    private fun load(language: GameLanguage) =
        WordBank(language, WordBank.parse(File(dir, language.wordFileName).readText()))

    @Test fun parseSkipsCommentsAndBlankLines() =
        assertEquals(listOf("PLANT", "ՔԱՂԱՔ"), WordBank.parse("# comment\n\n plant \r\nՔԱՂԱՔ\n"))

    @Test fun englishPlayableWordsAreFiveLetterUppercase() {
        val words = load(GameLanguage.ENGLISH).playableWords
        assertTrue(words.size >= 100)
        words.forEach { assertTrue(it, it.length == 5 && it.all { c -> c in 'A'..'Z' }) }
    }

    @Test fun armenianPlayableWordsAreFiveTokens() {
        val bank = load(GameLanguage.ARMENIAN)
        assertTrue(bank.playableWords.size >= 50)
        bank.playableWords.forEach { assertEquals(it, 5, GameLanguage.ARMENIAN.tokenize(it).size) }
        assertTrue(bank.isValidGuess("ԳԱՐՈՒՆ"))
    }

    @Test fun armenianKeyboardCoversEveryPlayableWord() {
        val keys = GameLanguage.ARMENIAN.keyboardRows.flatten()
            .filter { it != GameLanguage.KEY_ENTER && it != GameLanguage.KEY_DELETE }
            .flatMap { it.toList() }.toSet()
        for (word in load(GameLanguage.ARMENIAN).playableWords) for (c in word) {
            assertTrue("‘$c’ in $word is missing from the Armenian keyboard", c in keys)
        }
    }
}
