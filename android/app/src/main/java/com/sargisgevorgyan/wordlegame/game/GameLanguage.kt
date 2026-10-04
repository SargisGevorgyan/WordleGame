package com.sargisgevorgyan.wordlegame.game

import java.util.Locale

/**
 * Language selection for the game. Each language provides its word-list file,
 * on-screen keyboard layout and canonical letter casing. Mirrors the iOS
 * `GameLanguage` so both apps play identically.
 */
enum class GameLanguage(
    /** BCP-47 code; also the suffix of the shared word file (`words_<code>.txt`). */
    val code: String,
    /** The language's name in its own language. */
    val autonym: String,
    /** Title shown above the board. */
    val sampleTitle: String,
) {
    ENGLISH("en", "English", "WORDY"),
    ARMENIAN("hy", "Հայերեն", "ԲԱՌ-ԽԱՂ");

    /** Path of this language's word list inside the app's assets (from `shared/words`). */
    val wordFileName: String get() = "words_$code.txt"

    /**
     * Maps a typed character into the language's alphabet (uppercase), or `null`
     * when it isn't a letter of that alphabet. Ligatures whose uppercase expands
     * to more than one letter (e.g. `և`) are rejected.
     */
    fun normalize(character: Char): Char? {
        if (!character.isLetter()) return null
        val upper = character.uppercase()
        if (upper.length != 1) return null
        val c = upper[0]
        return when (this) {
            ENGLISH -> c.takeIf { it in 'A'..'Z' }
            ARMENIAN -> c.takeIf { it in 'Ա'..'֏' }
        }
    }

    /**
     * Splits a word into board tokens. English → one token per character.
     * Armenian → the ու digraph (`Ո` + `Ւ`) collapses into a single `"ՈՒ"` token,
     * because ու is one letter of the alphabet and occupies one tile.
     */
    fun tokenize(word: String): List<String> {
        val chars = word.uppercase()
        if (this == ENGLISH) return chars.map(Char::toString)
        val tokens = ArrayList<String>(chars.length)
        var i = 0
        while (i < chars.length) {
            if (chars[i] == 'Ո' && i + 1 < chars.length && chars[i + 1] == 'Ւ') {
                tokens += DIGRAPH_OU; i += 2
            } else {
                tokens += chars[i].toString(); i += 1
            }
        }
        return tokens
    }

    /** Rows of key tokens. [KEY_ENTER] and [KEY_DELETE] are action keys. */
    val keyboardRows: List<List<String>>
        get() = when (this) {
            ENGLISH -> listOf(
                listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", KEY_DELETE),
                listOf("A", "S", "D", "F", "G", "H", "J", "K", "L"),
                listOf("Z", "X", "C", "V", "B", "N", "M", KEY_ENTER),
            )
            // Armenian phonetic (KDWIN-style) layout — covers the full alphabet.
            // No և key: modern spelling writes it as Ե + Վ, and normalize() rejects it.
            ARMENIAN -> listOf(
                listOf("Է", "Թ", "Փ", "Ձ", "Ջ", "Ր", "Չ", "Ճ", "Ժ", KEY_DELETE),
                listOf("Ք", "Ո", "Ե", "Ռ", "Տ", "Ը", "Ւ", "Ի", "Օ", "Պ", "Խ", "Ծ"),
                listOf("Ա", "Ս", "Դ", "Ֆ", "Գ", "Հ", "Յ", "Կ", "Լ", "Շ"),
                listOf("Զ", "Ղ", "Ց", "Վ", "Բ", "Ն", "Մ", KEY_ENTER),
            )
        }

    /** True when a row exceeds 10 keys → shrink key metrics. */
    val keyboardIsCompact: Boolean get() = keyboardRows.any { it.size > 10 }

    companion object {
        const val KEY_ENTER = "ENTER"
        const val KEY_DELETE = "DELETE"
        const val DIGRAPH_OU = "ՈՒ"

        fun fromCode(code: String?): GameLanguage? = entries.firstOrNull { it.code == code }

        /** Armenian device language or Armenia region → Armenian; otherwise English. */
        fun systemDefault(locale: Locale = Locale.getDefault()): GameLanguage =
            if (locale.language == "hy" || locale.country == "AM") ARMENIAN else ENGLISH
    }
}
