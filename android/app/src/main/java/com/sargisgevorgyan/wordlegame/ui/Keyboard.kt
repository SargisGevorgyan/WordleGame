package com.sargisgevorgyan.wordlegame.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sargisgevorgyan.wordlegame.R
import com.sargisgevorgyan.wordlegame.game.GameLanguage
import com.sargisgevorgyan.wordlegame.game.LetterEvaluation

@Composable
fun Keyboard(
    language: GameLanguage,
    hints: Map<String, LetterEvaluation>,
    onKey: (String) -> Unit,
    modifier: Modifier = Modifier,
    hapticsEnabled: Boolean = true,
) {
    val compact = language.keyboardIsCompact
    val keyHeight = if (compact) 46.dp else 54.dp
    val gap = if (compact) 4.dp else 6.dp
    val haptics = LocalHapticFeedback.current
    Column(
        modifier = modifier
            .widthIn(max = 560.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(Palette.glassFill)
            .padding(horizontal = 6.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(gap),
    ) {
        // Every row is laid out on the widest row's grid, so keys stay the same width.
        val columns = language.keyboardRows.maxOf { row -> row.sumOf { weightOf(it).toDouble() } }.toFloat()
        language.keyboardRows.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(gap, Alignment.CenterHorizontally),
            ) {
                val rowWeight = row.sumOf { weightOf(it).toDouble() }.toFloat()
                // Centre shorter rows with side spacers.
                val pad = (columns - rowWeight) / 2f
                if (pad > 0f) Box(Modifier.weight(pad))
                row.forEach { token ->
                    Key(
                        token = token,
                        hint = hints[token],
                        height = keyHeight,
                        compact = compact,
                        modifier = Modifier.weight(weightOf(token)),
                        onClick = {
                            if (hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onKey(token)
                        },
                    )
                }
                if (pad > 0f) Box(Modifier.weight(pad))
            }
        }
    }
}

private fun weightOf(token: String) = when (token) {
    GameLanguage.KEY_ENTER, GameLanguage.KEY_DELETE -> 1.6f
    else -> 1f
}

@Composable
private fun Key(
    token: String,
    hint: LetterEvaluation?,
    height: Dp,
    compact: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(8.dp)
    val base = modifier.height(height).clip(shape)
    val background = when (token) {
        GameLanguage.KEY_ENTER -> base.background(Palette.enterGradient)
        GameLanguage.KEY_DELETE -> base.background(Palette.glassStroke)
        else -> base.background(if (hint != null) Palette.fill(hint, LocalHighContrast.current) else Palette.keyIdle)
    }
    val enterLabel = stringResource(R.string.enter)
    Box(background.clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        when (token) {
            GameLanguage.KEY_DELETE -> Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = stringResource(R.string.delete),
                tint = Color.White,
            )
            GameLanguage.KEY_ENTER -> Text(
                "↵",
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.semantics { contentDescription = enterLabel },
            )
            else -> Text(
                token,
                color = Color.White,
                fontSize = if (compact) 15.sp else 19.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
            )
        }
    }
}
