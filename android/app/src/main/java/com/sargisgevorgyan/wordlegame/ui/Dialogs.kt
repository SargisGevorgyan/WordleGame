package com.sargisgevorgyan.wordlegame.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.sargisgevorgyan.wordlegame.R
import com.sargisgevorgyan.wordlegame.game.GameLanguage
import com.sargisgevorgyan.wordlegame.game.Stats
import com.sargisgevorgyan.wordlegame.monetization.Entitlements

private val panelShape = RoundedCornerShape(28.dp)

@Composable
internal fun GlassPanel(content: @Composable () -> Unit) {
    Column(
        Modifier
            .widthIn(max = 420.dp)
            .fillMaxWidth()
            .background(Palette.indigoMid.copy(alpha = 0.97f), panelShape)
            .border(1.dp, Palette.glassStroke, panelShape)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) { content() }
}

@Composable
fun GameOverDialog(won: Boolean, word: String, stats: Stats, onPlayAgain: () -> Unit, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        GlassPanel {
            Text(
                stringResource(if (won) R.string.brilliant else R.string.so_close),
                color = if (won) Palette.neonGreen else Palette.warmYellow,
                fontSize = 30.sp,
                fontWeight = FontWeight.Black,
            )
            Text(
                stringResource(if (won) R.string.you_cracked_it else R.string.the_word_was),
                color = Palette.secondaryText,
            )
            Text(word, color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.Black, letterSpacing = 6.sp)
            StatsRow(stats)
            Box(
                Modifier
                    .fillMaxWidth()
                    .background(Palette.playAgainGradient, RoundedCornerShape(50))
                    .clickable(onClick = onPlayAgain)
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(R.string.play_again), color = Palette.indigoDeep, fontWeight = FontWeight.Black, fontSize = 18.sp)
            }
        }
    }
}

@Composable
fun StatsRow(stats: Stats) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
        StatCell(stats.gamesPlayed.toString(), stringResource(R.string.played))
        StatCell("${stats.winPercentage}%", stringResource(R.string.win_rate))
        StatCell(stats.currentStreak.toString(), stringResource(R.string.streak))
        StatCell(stats.maxStreak.toString(), stringResource(R.string.best))
    }
}

@Composable
private fun StatCell(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(label, color = Palette.secondaryText, fontSize = 12.sp, textAlign = TextAlign.Center)
    }
}

@Composable
fun SettingsDialog(
    current: GameLanguage,
    isInProgress: Boolean,
    stats: Stats,
    onLanguage: (GameLanguage) -> Unit,
    onResetStats: () -> Unit,
    entitlements: Entitlements,
    proMonthlyPrice: String?,
    privacyOptionsRequired: Boolean,
    onGoPro: () -> Unit,
    onRestore: () -> Unit,
    onPrivacyOptions: () -> Unit,
    onDismiss: () -> Unit,
) {
    var pending by remember { mutableStateOf<GameLanguage?>(null) }
    Dialog(onDismissRequest = onDismiss) {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            GlassPanel {
                Text(stringResource(R.string.settings), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)

                SectionTitle(stringResource(R.string.word_language))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GameLanguage.entries.forEach { language ->
                        val selected = language == current
                        val shape = RoundedCornerShape(16.dp)
                        Column(
                            Modifier
                                .weight(1f)
                                .background(if (selected) Palette.neonGreen.copy(alpha = 0.18f) else Palette.glassFill, shape)
                                .border(1.5.dp, if (selected) Palette.neonGreen else Palette.borderIdle, shape)
                                .clickable {
                                    when {
                                        selected -> Unit
                                        isInProgress -> pending = language
                                        else -> onLanguage(language)
                                    }
                                }
                                .padding(vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(language.sampleTitle, color = Color.White, fontWeight = FontWeight.Black)
                            Text(language.autonym, color = Palette.secondaryText, fontSize = 13.sp)
                        }
                    }
                }

                SectionTitle(stringResource(R.string.statistics))
                StatsRow(stats)
                TextButton(onClick = onResetStats) {
                    Text(stringResource(R.string.reset_statistics), color = Palette.auroraMagenta)
                }

                SectionTitle(stringResource(R.string.wordy_pro))
                when {
                    entitlements.isPro ->
                        Text(stringResource(R.string.youre_pro), color = Palette.neonGreen, fontWeight = FontWeight.Bold)
                    else -> {
                        if (entitlements.ownsRemoveAds) {
                            Text(stringResource(R.string.ads_removed), color = Palette.neonGreen, fontWeight = FontWeight.Bold)
                        }
                        TextButton(onClick = onGoPro) {
                            Text(
                                proMonthlyPrice?.let { stringResource(R.string.go_pro_from, it) } ?: stringResource(R.string.go_pro),
                                color = Palette.warmYellow,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = onRestore) {
                        Text(stringResource(R.string.restore_purchases), color = Color.White)
                    }
                    if (privacyOptionsRequired) {
                        TextButton(onClick = onPrivacyOptions) {
                            Text(stringResource(R.string.privacy_choices), color = Color.White)
                        }
                    }
                }

                Text(stringResource(R.string.how_to_play), color = Palette.secondaryText, fontSize = 13.sp)

                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.done), color = Palette.neonGreen, fontWeight = FontWeight.Bold)
                }
            }
        }
    }

    pending?.let { language ->
        AlertDialog(
            onDismissRequest = { pending = null },
            title = { Text(stringResource(R.string.start_new_game_in, language.autonym)) },
            text = { Text(stringResource(R.string.current_game_lost)) },
            confirmButton = {
                TextButton(onClick = { onLanguage(language); pending = null }) {
                    Text(stringResource(R.string.switch_and_restart))
                }
            },
            dismissButton = {
                TextButton(onClick = { pending = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text.uppercase(),
        color = Palette.secondaryText,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.fillMaxWidth(),
    )
}
