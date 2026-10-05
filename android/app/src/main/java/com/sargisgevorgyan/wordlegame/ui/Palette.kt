package com.sargisgevorgyan.wordlegame.ui

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.sargisgevorgyan.wordlegame.game.LetterEvaluation

/** Dark-indigo palette, matching the iOS app's `Color+Wordle.swift`. */
object Palette {
    val indigoTop = Color(0xFF1C1B4B)
    val indigoMid = Color(0xFF121233)
    val indigoDeep = Color(0xFF08081C)
    val auroraPurple = Color(0xFF7C3AED)
    val auroraBlue = Color(0xFF2563EB)
    val auroraMagenta = Color(0xFFDB2777)
    val auroraTeal = Color(0xFF14B8A6)

    val neonGreen = Color(0xFF2DE38B)
    val warmYellow = Color(0xFFF4C13B)
    val glassSlate = Color(0xFF3A3B52)

    // High contrast (colour-blind friendly): orange = right spot, blue = wrong spot.
    val contrastOrange = Color(0xFFF5793A)
    val contrastBlue = Color(0xFF85C0F9)

    val glassFill = Color.White.copy(alpha = 0.06f)
    val glassStroke = Color.White.copy(alpha = 0.18f)
    val keyIdle = Color.White.copy(alpha = 0.10f)
    val tileEmpty = Color.White.copy(alpha = 0.05f)
    val borderIdle = Color.White.copy(alpha = 0.12f)
    val borderActive = Color.White.copy(alpha = 0.45f)
    val secondaryText = Color.White.copy(alpha = 0.55f)

    val backdrop = Brush.linearGradient(listOf(indigoTop, indigoMid, indigoDeep))
    val enterGradient = Brush.linearGradient(listOf(auroraPurple, auroraBlue))
    val playAgainGradient = Brush.linearGradient(listOf(neonGreen, auroraTeal))

    fun fill(evaluation: LetterEvaluation, highContrast: Boolean = false): Color = when (evaluation) {
        LetterEvaluation.CORRECT -> if (highContrast) contrastOrange else neonGreen
        LetterEvaluation.PRESENT -> if (highContrast) contrastBlue else warmYellow
        LetterEvaluation.ABSENT -> glassSlate
        LetterEvaluation.EMPTY, LetterEvaluation.TBD -> tileEmpty
    }
}

/** True when the player picked the high-contrast palette in Settings. */
val LocalHighContrast = compositionLocalOf { false }
