package com.sargisgevorgyan.wordlegame.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.key.utf16CodePoint
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sargisgevorgyan.wordlegame.GameViewModel
import com.sargisgevorgyan.wordlegame.R
import com.sargisgevorgyan.wordlegame.WordleApplication
import com.sargisgevorgyan.wordlegame.game.GameMode
import com.sargisgevorgyan.wordlegame.game.GameStatus
import com.sargisgevorgyan.wordlegame.monetization.BannerAd
import com.sargisgevorgyan.wordlegame.monetization.Links
import com.sargisgevorgyan.wordlegame.monetization.Products
import com.sargisgevorgyan.wordlegame.monetization.yearlySavingsPercent
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun WordleApp(vm: GameViewModel = viewModel()) {
    MaterialTheme(colorScheme = darkColorScheme(primary = Palette.neonGreen, background = Palette.indigoDeep)) {
        var showSettings by rememberSaveable { mutableStateOf(false) }
        var showHintStore by rememberSaveable { mutableStateOf(false) }
        var showPro by rememberSaveable { mutableStateOf(false) }
        val context = LocalContext.current
        val activity = remember(context) { context.findActivity() }
        val uriHandler = LocalUriHandler.current
        val app = context.applicationContext as WordleApplication
        val billing = app.billing
        val ads = app.ads
        val entitlements by billing.entitlements.collectAsState()
        val products by billing.products.collectAsState()
        val purchasing by billing.purchasing.collectAsState()
        val canRequestAds by ads.canRequestAds.collectAsState()
        val rewardedReady by ads.rewardedReady.collectAsState()
        val privacyOptionsRequired by ads.privacyOptionsRequired.collectAsState()
        // Re-read prices whenever product details arrive.
        val proMonthlyPrice = remember(products) { billing.proPrice(Products.ProPlan.MONTHLY) }
        val playAgain = {
            ads.maybeShowInterstitial(activity, entitlements.isAdFree)
            if (vm.mode == GameMode.DAILY) vm.changeMode(GameMode.FREE) else vm.newGame()
        }
        // Intro after the system splash; saveable so rotation doesn't replay it.
        var showIntro by rememberSaveable { mutableStateOf(true) }
        val focus = remember { FocusRequester() }
        LaunchedEffect(Unit) { focus.requestFocus() }
        // A new day may have started while the app was in the background.
        LifecycleResumeEffect(Unit) {
            vm.refreshDaily()
            onPauseOrDispose {}
        }
        val share = { shareResult(context, vm.shareText) }

        Box(
            Modifier
                .fillMaxSize()
                .background(Palette.backdrop)
                // Physical keyboard: letters, Enter = submit, Backspace = delete.
                .onKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                    when (event.key) {
                        Key.Enter, Key.NumPadEnter -> { vm.submit(); true }
                        Key.Backspace, Key.Delete -> { vm.delete(); true }
                        else -> {
                            val code = event.utf16CodePoint
                            if (code > 0 && Character.isLetter(code)) {
                                vm.onTypedChar(code.toChar()); true
                            } else false
                        }
                    }
                }
                .focusRequester(focus)
                .focusable(),
        ) {
            AuroraBackground()
            Column(
                Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Hud(
                    hints = if (vm.hasUnlimitedHints) "∞" else vm.hintsRemaining.toString(),
                    isPro = entitlements.isPro,
                    onHint = {
                        when {
                            // Daily mode: useHint explains that hints are off.
                            vm.mode == GameMode.DAILY || vm.canUseHint -> vm.useHint()
                            vm.state.status == GameStatus.PLAYING -> showHintStore = true
                        }
                    },
                    onPro = { showPro = true },
                    onShare = share.takeIf { vm.state.status != GameStatus.PLAYING },
                    onSettings = { showSettings = true },
                )
                Text(
                    vm.state.language.sampleTitle,
                    style = TextStyle(
                        color = Color.White,
                        fontSize = 30.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 4.sp,
                        shadow = Shadow(Palette.auroraPurple, Offset.Zero, blurRadius = 24f),
                    ),
                    modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
                )
                ModePicker(
                    mode = vm.mode,
                    puzzleNumber = vm.puzzleNumber,
                    enabled = !vm.isRevealing,
                    onMode = vm::changeMode,
                )
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Board(vm.state, vm.revealingRow, vm.shakeToken)
                    ToastBanner(vm.toast, Modifier.align(Alignment.TopCenter))
                }
                Spacer(Modifier.height(10.dp))
                Keyboard(
                    language = vm.state.language,
                    hints = vm.state.keyboardHints,
                    onKey = vm::onKey,
                    modifier = Modifier.padding(bottom = 8.dp),
                )
                if (canRequestAds && !entitlements.isAdFree) {
                    BannerAd(Modifier.padding(bottom = 4.dp))
                }
            }
            AnimatedVisibility(showIntro, enter = EnterTransition.None, exit = fadeOut(tween(350))) {
                SplashIntro(vm.state.language.sampleTitle, onFinished = { showIntro = false })
            }
        }

        if (vm.showGameOver) {
            GameOverDialog(
                won = vm.state.status == GameStatus.WON,
                word = vm.state.targetWord,
                stats = vm.stats,
                puzzleNumber = vm.puzzleNumber,
                onShare = share,
                onPlayAgain = playAgain,
                onNewDay = vm::refreshDaily,
                // Back / tap outside also moves on: a new free game, or back to the finished daily board.
                onDismiss = vm::newGame,
            )
        }
        if (showSettings) {
            SettingsDialog(
                current = vm.state.language,
                isInProgress = vm.languageSwitchLosesGame,
                stats = vm.stats,
                onLanguage = vm::changeLanguage,
                onResetStats = vm::resetStats,
                entitlements = entitlements,
                proMonthlyPrice = proMonthlyPrice,
                privacyOptionsRequired = privacyOptionsRequired,
                onGoPro = { showSettings = false; showPro = true },
                onRestore = billing::restorePurchases,
                onPrivacyOptions = { ads.showPrivacyOptions(activity) },
                onDismiss = { showSettings = false },
            )
        }
        if (showHintStore) {
            LaunchedEffect(Unit) { ads.loadRewardedIfNeeded() }
            // Close once hints arrive (a pack or Pro); the game toasts "+hints".
            LaunchedEffect(vm.canUseHint) { if (vm.canUseHint) showHintStore = false }
            HintStoreDialog(
                hints = vm.hintsRemaining,
                rewardedReady = rewardedReady,
                packs = remember(products) {
                    Products.hintPacks.map { (id, count) -> HintPackOffer(id, count, billing.price(id)) }
                },
                proMonthlyPrice = proMonthlyPrice,
                onWatchAd = { done ->
                    ads.showRewarded(activity) { granted ->
                        done()
                        vm.addHints(granted)
                    }
                },
                onBuy = { billing.buy(activity, it) },
                onGoPro = { showHintStore = false; showPro = true },
                onDismiss = { showHintStore = false },
            )
        }
        if (showPro) {
            LaunchedEffect(entitlements.isPro) { if (entitlements.isPro) showPro = false }
            ProDialog(
                entitlements = entitlements,
                monthlyPrice = proMonthlyPrice,
                yearlyPrice = remember(products) { billing.proPrice(Products.ProPlan.YEARLY) },
                yearlySavings = remember(products) {
                    val monthly = billing.proPriceMicros(Products.ProPlan.MONTHLY)
                    val yearly = billing.proPriceMicros(Products.ProPlan.YEARLY)
                    if (monthly != null && yearly != null) yearlySavingsPercent(monthly, yearly) else null
                },
                removeAdsPrice = remember(products) { billing.price(Products.REMOVE_ADS) },
                purchasing = purchasing,
                onSubscribe = { billing.buyPro(activity, it) },
                onRemoveAds = { billing.buy(activity, Products.REMOVE_ADS) },
                onRestore = billing::restorePurchases,
                onManage = { uriHandler.openUri(Links.manageSubscription(context.packageName)) },
                onPrivacyPolicy = { uriHandler.openUri(Links.PRIVACY_POLICY) },
                onDismiss = { showPro = false },
            )
        }
    }
}

/** Opens the system share sheet with the emoji result grid. */
private fun shareResult(context: Context, text: String) {
    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
    context.startActivity(Intent.createChooser(send, null))
}

@Composable
private fun ModePicker(mode: GameMode, puzzleNumber: Int?, enabled: Boolean, onMode: (GameMode) -> Unit) {
    Row(
        Modifier
            .padding(bottom = 6.dp)
            .background(Palette.glassFill, RoundedCornerShape(50))
            .padding(4.dp),
    ) {
        GameMode.entries.forEach { option ->
            val selected = option == mode
            val label = when (option) {
                GameMode.DAILY -> puzzleNumber?.let { stringResource(R.string.daily_number, it) }
                    ?: stringResource(R.string.daily)
                GameMode.FREE -> stringResource(R.string.free_play)
            }
            Text(
                label,
                color = if (selected) Palette.indigoDeep else Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                modifier = Modifier
                    .background(if (selected) Palette.neonGreen else Color.Transparent, RoundedCornerShape(50))
                    .clickable(enabled = enabled && !selected) { onMode(option) }
                    .padding(horizontal = 16.dp, vertical = 6.dp),
            )
        }
    }
}

@Composable
private fun Hud(
    hints: String,
    isPro: Boolean,
    onHint: () -> Unit,
    onPro: () -> Unit,
    onShare: (() -> Unit)?,
    onSettings: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .background(Palette.glassFill, RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            "💡 $hints",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .background(Palette.keyIdle, CircleShape)
                .clickable(onClick = onHint)
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
        Spacer(Modifier.weight(1f))
        Text(
            if (isPro) stringResource(R.string.pro) else "👑 " + stringResource(R.string.go_pro),
            color = Color.White,
            fontWeight = FontWeight.Black,
            fontSize = 13.sp,
            modifier = Modifier
                .background(
                    if (isPro) Brush.linearGradient(listOf(Palette.warmYellow, Palette.auroraMagenta)) else Palette.enterGradient,
                    CircleShape,
                )
                .clickable(onClick = onPro)
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
        if (onShare != null) {
            IconButton(onClick = onShare) {
                Icon(Icons.Filled.Share, contentDescription = stringResource(R.string.share), tint = Color.White)
            }
        }
        IconButton(onClick = onSettings) {
            Icon(Icons.Filled.Settings, contentDescription = stringResource(R.string.settings), tint = Color.White)
        }
    }
}

/** The activity hosting this composition (billing and full-screen ads need one). */
private tailrec fun Context.findActivity(): Activity = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> error("No activity in context")
}

@Composable
private fun ToastBanner(message: Int?, modifier: Modifier = Modifier) {
    var last by remember { mutableStateOf(message) }
    if (message != null) last = message
    AnimatedVisibility(message != null, modifier = modifier, enter = fadeIn(), exit = fadeOut()) {
        Text(
            last?.let { stringResource(it) }.orEmpty(),
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .background(Palette.indigoTop.copy(alpha = 0.95f), RoundedCornerShape(14.dp))
                .padding(horizontal = 18.dp, vertical = 10.dp),
        )
    }
}

/** Slowly drifting blurred aurora glows (iOS: `AnimatedBackground`). */
@Composable
private fun AuroraBackground() {
    val t by rememberInfiniteTransition(label = "aurora").animateFloat(
        initialValue = 0f,
        targetValue = (2 * Math.PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(24_000, easing = LinearEasing), RepeatMode.Restart),
        label = "phase",
    )
    val blobs = listOf(
        Palette.auroraPurple to Offset(0.2f, 0.15f),
        Palette.auroraBlue to Offset(0.85f, 0.3f),
        Palette.auroraMagenta to Offset(0.25f, 0.75f),
        Palette.auroraTeal to Offset(0.8f, 0.9f),
    )
    Canvas(Modifier.fillMaxSize()) {
        blobs.forEachIndexed { i, (colour, anchor) ->
            val phase = t + i * 1.7f
            val centre = Offset(
                size.width * (anchor.x + 0.08f * cos(phase)),
                size.height * (anchor.y + 0.05f * sin(phase)),
            )
            val radius = size.minDimension * 0.55f
            drawCircle(
                Brush.radialGradient(listOf(colour.copy(alpha = 0.28f), Color.Transparent), centre, radius),
                radius,
                centre,
            )
        }
    }
}
