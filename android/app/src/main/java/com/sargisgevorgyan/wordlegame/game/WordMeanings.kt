package com.sargisgevorgyan.wordlegame.game

/**
 * Short meanings shown after each game, from the shared
 * `shared/words/meanings_<code>.txt` (also bundled by the iOS app).
 * Armenian words carry an English gloss.
 */
object WordMeanings {
    /** `WORD|meaning` per line; blank lines and `#` comments are ignored. Words are UPPERCASE keys. */
    fun parse(text: String): Map<String, String> = text.lineSequence()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && '|' in it }
        .map { it.substringBefore('|').trim().uppercase() to it.substringAfter('|').trim() }
        .filter { (word, meaning) -> word.isNotEmpty() && meaning.isNotEmpty() }
        .toMap()
}
