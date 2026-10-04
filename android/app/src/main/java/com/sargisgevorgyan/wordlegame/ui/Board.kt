package com.sargisgevorgyan.wordlegame.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sargisgevorgyan.wordlegame.GameViewModel
import com.sargisgevorgyan.wordlegame.game.GameState
import com.sargisgevorgyan.wordlegame.game.LetterEvaluation
import com.sargisgevorgyan.wordlegame.game.Tile
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

@Composable
fun Board(state: GameState, revealingRow: Int, shakeToken: Int, modifier: Modifier = Modifier) {
    val shake = remember { Animatable(0f) }
    LaunchedEffect(shakeToken) {
        if (shakeToken == 0) return@LaunchedEffect
        for (x in listOf(-14f, 12f, -9f, 6f, -3f, 0f)) shake.animateTo(x, tween(45))
    }
    Column(
        modifier = modifier.widthIn(max = 340.dp).fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        state.board.forEachIndexed { rowIndex, row ->
            val rowModifier = if (rowIndex == state.currentRow) {
                Modifier.offset { IntOffset(shake.value.roundToInt(), 0) }
            } else Modifier
            Row(rowModifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEachIndexed { col, tile ->
                    TileView(
                        tile = tile,
                        flipDelayMillis = if (rowIndex == revealingRow) col * GameViewModel.FLIP_STAGGER_MILLIS else 0,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun TileView(tile: Tile, flipDelayMillis: Int, modifier: Modifier = Modifier) {
    val revealed = tile.evaluation.rank > 0
    // Flip: rotate 0→90 showing the blank face, swap colours, then 90→0 (iOS: spring flip).
    val rotation = remember { Animatable(0f) }
    val showColour = remember { Animatable(if (revealed) 1f else 0f) }
    LaunchedEffect(revealed) {
        if (revealed && showColour.value == 0f) {
            delay(flipDelayMillis.toLong())
            rotation.animateTo(90f, tween(180))
            showColour.snapTo(1f)
            rotation.animateTo(0f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow))
        } else if (!revealed) {
            showColour.snapTo(0f); rotation.snapTo(0f)
        }
    }
    // Pop when a letter is entered.
    val scale = remember { Animatable(1f) }
    LaunchedEffect(tile.letter) {
        if (tile.letter != null && !revealed) {
            scale.snapTo(1.12f)
            scale.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium))
        }
    }

    val coloured = showColour.value > 0.5f
    val fill = if (coloured) Palette.fill(tile.evaluation, LocalHighContrast.current) else Palette.tileEmpty
    val border = when {
        coloured -> Color.Transparent
        tile.evaluation == LetterEvaluation.TBD -> Palette.borderActive
        else -> Palette.borderIdle
    }
    val shape = RoundedCornerShape(10.dp)
    Box(
        modifier = modifier
            .aspectRatio(1f)
            .graphicsLayer {
                rotationX = rotation.value
                scaleX = scale.value; scaleY = scale.value
                cameraDistance = 12f * density
            }
            .background(fill, shape)
            .border(2.dp, border, shape),
        contentAlignment = Alignment.Center,
    ) {
        val text = tile.letter.orEmpty()
        Text(
            text = text,
            color = Color.White,
            fontSize = if (text.length > 1) 20.sp else 28.sp,
            fontWeight = FontWeight.Black,
        )
    }
}
