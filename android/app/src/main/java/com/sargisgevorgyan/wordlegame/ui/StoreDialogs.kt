package com.sargisgevorgyan.wordlegame.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.sargisgevorgyan.wordlegame.R
import com.sargisgevorgyan.wordlegame.monetization.Entitlements
import com.sargisgevorgyan.wordlegame.monetization.Products.ProPlan

private val rowShape = RoundedCornerShape(14.dp)
private val proGradient = Brush.linearGradient(listOf(Palette.warmYellow, Palette.auroraMagenta))

/** A hint pack row: product id, hint count and its Play price (null until loaded). */
data class HintPackOffer(val productId: String, val hints: Int, val price: String?)

/** Shown when the player taps the hint pill with no hints left (iOS: `HintStoreView`). */
@Composable
fun HintStoreDialog(
    hints: Int,
    rewardedReady: Boolean,
    packs: List<HintPackOffer>,
    proMonthlyPrice: String?,
    onWatchAd: (onDone: () -> Unit) -> Unit,
    onBuy: (productId: String) -> Unit,
    onGoPro: () -> Unit,
    onDismiss: () -> Unit,
) {
    var watching by rememberSaveable { mutableStateOf(false) }
    Dialog(onDismissRequest = onDismiss) {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            GlassPanel {
                Text("💡", fontSize = 34.sp)
                Text(stringResource(R.string.out_of_hints), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Black)
                Text(stringResource(R.string.you_have_left, hints), color = Palette.secondaryText)

                StoreRow(
                    title = stringResource(R.string.watch_video),
                    subtitle = stringResource(R.string.watch_video_reward, 1),
                    background = Palette.playAgainGradient,
                    enabled = rewardedReady && !watching,
                    loading = watching,
                    onClick = {
                        watching = true
                        onWatchAd { watching = false }
                    },
                )
                StoreRow(
                    title = stringResource(R.string.unlimited_hints_with_pro),
                    subtitle = proMonthlyPrice?.let { stringResource(R.string.pro_from_price, it) },
                    background = proGradient,
                    onClick = onGoPro,
                )
                packs.forEach { pack ->
                    StoreRow(
                        title = stringResource(R.string.hint_pack, pack.hints),
                        trailing = pack.price ?: "—",
                        enabled = pack.price != null,
                        onClick = { onBuy(pack.productId) },
                    )
                }
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.maybe_later), color = Palette.secondaryText, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/** "Wordy Pro" paywall (iOS: `ProView`). */
@Composable
fun ProDialog(
    entitlements: Entitlements,
    monthlyPrice: String?,
    yearlyPrice: String?,
    yearlySavings: Int?,
    removeAdsPrice: String?,
    purchasing: Boolean,
    onSubscribe: (ProPlan) -> Unit,
    onRemoveAds: () -> Unit,
    onRestore: () -> Unit,
    onManage: () -> Unit,
    onPrivacyPolicy: () -> Unit,
    onDismiss: () -> Unit,
) {
    var plan by rememberSaveable { mutableStateOf(ProPlan.YEARLY) }
    Dialog(onDismissRequest = onDismiss) {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            GlassPanel {
                Text("👑", fontSize = 36.sp)
                Text(stringResource(R.string.wordy_pro), color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Black)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Feature(stringResource(R.string.pro_no_ads))
                    Feature(stringResource(R.string.pro_unlimited_hints))
                }

                if (entitlements.isPro) {
                    Text(stringResource(R.string.youre_pro), color = Palette.neonGreen, fontWeight = FontWeight.Bold)
                    TextButton(onClick = onManage) {
                        Text(stringResource(R.string.manage_subscription), color = Color.White)
                    }
                } else {
                    PlanRow(
                        title = stringResource(R.string.monthly),
                        price = monthlyPrice,
                        period = stringResource(R.string.per_month),
                        badge = null,
                        selected = plan == ProPlan.MONTHLY,
                        onClick = { plan = ProPlan.MONTHLY },
                    )
                    PlanRow(
                        title = stringResource(R.string.yearly),
                        price = yearlyPrice,
                        period = stringResource(R.string.per_year),
                        badge = yearlySavings?.let { stringResource(R.string.save_percent, it) },
                        selected = plan == ProPlan.YEARLY,
                        onClick = { plan = ProPlan.YEARLY },
                    )
                    val canSubscribe = !purchasing && (if (plan == ProPlan.MONTHLY) monthlyPrice else yearlyPrice) != null
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .alpha(if (canSubscribe) 1f else 0.5f)
                            .background(Palette.playAgainGradient, RoundedCornerShape(50))
                            .clickable(enabled = canSubscribe) { onSubscribe(plan) }
                            .padding(vertical = 14.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(stringResource(R.string.continue_label), color = Palette.indigoDeep, fontWeight = FontWeight.Black, fontSize = 18.sp)
                    }
                    if (!entitlements.ownsRemoveAds && removeAdsPrice != null) {
                        TextButton(onClick = onRemoveAds, enabled = !purchasing) {
                            Text(stringResource(R.string.just_remove_ads, removeAdsPrice), color = Color.White.copy(alpha = 0.85f))
                        }
                    }
                }

                TextButton(onClick = onRestore) {
                    Text(stringResource(R.string.restore_purchases), color = Color.White.copy(alpha = 0.8f))
                }
                Text(
                    stringResource(R.string.subscription_terms),
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                )
                Text(
                    stringResource(R.string.privacy_policy),
                    color = Color.White.copy(alpha = 0.75f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(onClick = onPrivacyPolicy).padding(4.dp),
                )
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.maybe_later), color = Palette.secondaryText, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun Feature(text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("✓", color = Palette.neonGreen, fontWeight = FontWeight.Black, fontSize = 18.sp)
        Spacer(Modifier.width(10.dp))
        Text(text, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun PlanRow(
    title: String,
    price: String?,
    period: String,
    badge: String?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Palette.glassFill, rowShape)
            .border(2.dp, if (selected) Palette.neonGreen else Palette.borderIdle, rowShape)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(if (selected) "●" else "○", color = if (selected) Palette.neonGreen else Palette.secondaryText)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, color = Color.White, fontWeight = FontWeight.Bold)
            badge?.let { Text(it, color = Palette.neonGreen, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
        }
        Text(price ?: "—", color = Color.White, fontWeight = FontWeight.Bold)
        Text(" $period", color = Palette.secondaryText, fontSize = 12.sp)
    }
}

@Composable
private fun StoreRow(
    title: String,
    subtitle: String? = null,
    trailing: String? = null,
    background: Brush? = null,
    enabled: Boolean = true,
    loading: Boolean = false,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .alpha(if (enabled || loading) 1f else 0.5f)
            .then(if (background != null) Modifier.background(background, rowShape) else Modifier.background(Palette.glassFill, rowShape))
            .border(1.dp, Palette.glassStroke, rowShape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            subtitle?.let { Text(it, color = Color.White.copy(alpha = 0.75f), fontSize = 12.sp) }
        }
        when {
            loading -> CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
            trailing != null -> Text(trailing, color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}
