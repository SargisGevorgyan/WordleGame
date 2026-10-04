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
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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

private val panelShape = RoundedCornerShape(28.dp)

@Composable
private fun GlassPanel(content: @Composable () -> Unit) {
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
fun GameOverDialog(
    won: Boolean,
    timedOut: Boolean,
    word: String,
    meaning: String?,
    wordOfTheDay: Pair<String, String>?,
    stats: Stats,
    onPlayAgain: () -> Unit,
    onDismiss: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        GlassPanel {
            Text(
                stringResource(
                    when {
                        won -> R.string.brilliant
                        timedOut -> R.string.times_up
                        else -> R.string.so_close
                    },
                ),
                color = if (won) Palette.neonGreen else Palette.warmYellow,
                fontSize = 30.sp,
                fontWeight = FontWeight.Black,
            )
            Text(
                stringResource(if (won) R.string.you_cracked_it else R.string.the_word_was),
                color = Palette.secondaryText,
            )
            Text(word, color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.Black, letterSpacing = 6.sp)
            if (meaning != null) {
                Text(
                    "${stringResource(R.string.meaning)}: $meaning",
                    color = Palette.warmYellow,
                    fontSize = 16.sp,
                    textAlign = TextAlign.Center,
                )
            }
            StatsRow(stats)
            // Learners: one Armenian word a day, skipped when it's the word just played.
            wordOfTheDay?.takeIf { it.first != word }?.let { (hyWord, gloss) -> WordOfTheDayCard(hyWord, gloss) }
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
private fun WordOfTheDayCard(word: String, gloss: String) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .background(Palette.glassFill, shape)
            .border(1.dp, Palette.borderIdle, shape)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(stringResource(R.string.word_of_the_day).uppercase(), color = Palette.secondaryText, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        Text(word, color = Palette.neonGreen, fontSize = 22.sp, fontWeight = FontWeight.Black, letterSpacing = 3.sp)
        Text(gloss, color = Color.White, fontSize = 14.sp, textAlign = TextAlign.Center)
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
    hardMode: Boolean,
    timedMode: Boolean,
    onLanguage: (GameLanguage) -> Unit,
    onHardMode: (Boolean) -> Unit,
    onTimedMode: (Boolean) -> Unit,
    onResetStats: () -> Unit,
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

                SectionTitle(stringResource(R.string.game_modes))
                ModeSwitch(stringResource(R.string.hard_mode), stringResource(R.string.hard_mode_desc), hardMode, onHardMode)
                ModeSwitch(stringResource(R.string.timed_mode), stringResource(R.string.timed_mode_desc), timedMode, onTimedMode)
                if (isInProgress) {
                    Text(stringResource(R.string.modes_next_game), color = Palette.secondaryText, fontSize = 12.sp, modifier = Modifier.fillMaxWidth())
                }

                SectionTitle(stringResource(R.string.statistics))
                StatsRow(stats)
                TextButton(onClick = onResetStats) {
                    Text(stringResource(R.string.reset_statistics), color = Palette.auroraMagenta)
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
private fun ModeSwitch(title: String, description: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(description, color = Palette.secondaryText, fontSize = 12.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(checkedTrackColor = Palette.neonGreen, checkedThumbColor = Palette.indigoDeep),
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
