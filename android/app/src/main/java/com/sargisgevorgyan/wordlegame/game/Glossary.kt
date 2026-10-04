package com.sargisgevorgyan.wordlegame.game

/**
 * English meanings for words, parsed from the shared `shared/words/glosses_<code>.tsv`
 * (also read by the iOS app). Used for the post-game meaning and the
 * Armenian word of the day.
 */
class Glossary(val entries: List<Pair<String, String>>) {

    private val map: Map<String, String> = entries.toMap()

    fun meaning(word: String): String? = map[word.uppercase()]

    /**
     * The word of the day for [epochDay] (days since 1970-01-01 in the player's
     * calendar), chosen from the glossed words that are playable in [bank].
     * Same day → same word on iOS and Android.
     */
    fun wordOfTheDay(epochDay: Long, bank: WordBank): Pair<String, String>? {
        val playable = bank.playableWords.toHashSet()
        val candidates = entries.filter { it.first in playable }
        if (candidates.isEmpty()) return null
        return candidates[dayIndex(epochDay, candidates.size)]
    }

    companion object {
        /** Spreads consecutive days across the list (7919 is prime). */
        fun dayIndex(epochDay: Long, count: Int): Int = Math.floorMod(epochDay * 7919, count.toLong()).toInt()

        /** `WORD<TAB>gloss` per line; blank lines and `#` comments are ignored. */
        fun parse(text: String): Glossary = Glossary(
            text.lineSequence()
                .map { it.trim() }
                .filter { it.isNotEmpty() && !it.startsWith("#") }
                .mapNotNull { line ->
                    val tab = line.indexOf('\t')
                    if (tab <= 0) return@mapNotNull null
                    val gloss = line.substring(tab + 1).trim()
                    if (gloss.isEmpty()) null else line.substring(0, tab).trim().uppercase() to gloss
                }
                .toList(),
        )
    }
}
