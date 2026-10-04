package com.sargisgevorgyan.wordlegame.game

import kotlin.random.Random

/**
 * Word list for one language, parsed from the shared word bank
 * (`shared/words/words_<code>.txt` at the repo root, also used by the iOS app).
 */
class WordBank(val language: GameLanguage, rawWords: List<String>) {

    /** Words whose tokenised length is exactly [GameRules.WORD_LENGTH], so they fit the board. */
    val playableWords: List<String> = rawWords
        .map { it.uppercase() }
        .filter { language.tokenize(it).size == GameRules.WORD_LENGTH }
        .distinct()

    private val playableSet: Set<String> = playableWords.toHashSet()

    fun isValidGuess(guess: String): Boolean = guess.uppercase() in playableSet

    fun randomWord(random: Random = Random.Default): String = playableWords.random(random)

    companion object {
        /** One word per line; blank lines and `#` comments are ignored. */
        fun parse(text: String): List<String> = text.lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") }
            .map { it.uppercase() }
            .toList()
    }
}
