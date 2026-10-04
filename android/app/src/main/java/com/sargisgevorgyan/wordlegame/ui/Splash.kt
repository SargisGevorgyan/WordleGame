package com.sargisgevorgyan.wordlegame.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Same geometry as res/drawable/ic_splash.xml as the system splash draws it
// (and the iOS LaunchLogo): a ~93dp square of 2x2 tiles.
private val TileSize = 42.dp
private val TileGap = 9.dp
private val LogoSize = TileSize * 2 + TileGap
private val TileColors = listOf(Palette.neonGreen, Palette.warmYellow, Palette.glassSlate, Palette.neonGreen)

/**
 * Brief animated intro shown after the system splash (iOS: `SplashView`). Its
 * first frame equals the splash, so the hand-off is seamless; each tile bumps
 * in turn, the title glows in, then [onFinished] lets the caller fade it away.
 */
@Composable
fun SplashIntro(title: String, onFinished: () -> Unit) {
    val finished by rememberUpdatedState(onFinished)
    val bumps = remember { List(4) { Animatable(1f) } }
    val titleIn = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        bumps.forEach { bump ->
            launch {
                bump.animateTo(1.14f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium))
                bump.animateTo(1f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow))
            }
            delay(110)
        }
        titleIn.animateTo(1f, tween(450, easing = FastOutSlowInEasing))
        delay(850)
        finished()
    }

    Box(Modifier.fillMaxSize().background(Palette.indigoDeep), contentAlignment = Alignment.Center) {
        Column(Modifier.size(LogoSize), verticalArrangement = Arrangement.spacedBy(TileGap)) {
            repeat(2) { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(TileGap)) {
                    repeat(2) { column ->
                        val index = row * 2 + column
                        val color = TileColors[index]
                        val bump = bumps[index].value
                        val shape = RoundedCornerShape(TileSize * 3 / 19)
                        Box(
                            Modifier
                                .size(TileSize)
                                .scale(bump)
                                .shadow(
                                    elevation = (((bump - 1f) / 0.14f).coerceIn(0f, 1f) * 12).dp,
                                    shape = shape,
                                    ambientColor = color,
                                    spotColor = color,
                                )
                                .background(color, shape),
                        )
                    }
                }
            }
        }
        Text(
            title,
            style = TextStyle(
                brush = Brush.verticalGradient(listOf(Color.White, Palette.neonGreen, Palette.auroraTeal)),
                fontSize = 36.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 1.sp,
                shadow = Shadow(Palette.neonGreen.copy(alpha = 0.9f), Offset.Zero, blurRadius = 24f),
            ),
            modifier = Modifier
                .offset(y = LogoSize / 2 + 40.dp + 16.dp * (1 - titleIn.value))
                .graphicsLayer { alpha = titleIn.value },
        )
    }
}
