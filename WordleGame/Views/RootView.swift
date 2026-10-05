//
//  RootView.swift
//  WordleGame
//
//  Premium game screen: animated aurora backdrop, glass HUD, neon title,
//  3D board, frosted keyboard and a frosted end-game modal.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdManager
    @EnvironmentObject private var gameCenter: GameCenterManager

    @AppStorage("isAdFree") private var isAdFree = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage(GameLanguage.storageKey) private var languageRaw = GameLanguage.systemDefault.rawValue

    @State private var showSettings = false
    @State private var showHintStore = false
    @State private var showLeaderboard = false
    @FocusState private var keyboardFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private var title: String {
        switch game.language {
        case .english:  return "WORDY"
        case .armenian: return "ԲԱՌ-ԽԱՂ"
        }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                hudBar
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                titleView
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                modePicker
                    .padding(.top, 4)

                Spacer(minLength: 4)

                BoardView(
                    board: game.board,
                    currentRow: game.currentRow,
                    shakeToken: game.shakeToken
                )

                Spacer(minLength: 4)

                KeyboardView(
                    rows: game.keyboardRows,
                    compact: game.keyboardIsCompact,
                    hints: game.keyboardHints,
                    onKey: game.enterKey,
                    onEnter: game.submit,
                    onDelete: game.deleteLetter
                )
                .padding(.bottom, 4)

                if !isAdFree {
                    BannerAdContainer(isAdFree: isAdFree)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            gameOverOverlay
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) { toast }
        .focusable()
        .focused($keyboardFocused)
        .focusEffectDisabled()
        .onKeyPress { press in
            game.handleKeyPress(press) ? .handled : .ignored
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showHintStore) { HintStoreView() }
        .sheet(isPresented: $showLeaderboard) {
            GameCenterView(leaderboardID: GameCenterManager.streakLeaderboardID)
                .ignoresSafeArea()
        }
        .task {
            SoundManager.shared.isEnabled = soundEnabled
            keyboardFocused = true
            CloudStatsSync.shared.start()
            gameCenter.authenticate()
            game.onRoundFinished = { _ in
                ads.registerRoundCompleted(isAdFree: store.isAdFree)
                gameCenter.submitStats()
            }
            store.onHintsGranted = { count in game.addHints(count) }
        }
        .onChange(of: showSettings) { _, showing in
            if !showing { keyboardFocused = true }
        }
        .onChange(of: showHintStore) { _, showing in
            if !showing { keyboardFocused = true }
        }
        .onChange(of: showLeaderboard) { _, showing in
            if !showing { keyboardFocused = true }
        }
        .onChange(of: scenePhase) { _, phase in
            // A new day may have started while the app was in the background.
            if phase == .active { game.refreshDailyIfNeeded() }
        }
        .onChange(of: languageRaw) { _, raw in
            guard let language = GameLanguage(rawValue: raw) else { return }
            game.changeLanguage(language)
            keyboardFocused = true
        }
    }

    // MARK: - HUD

    private var hudBar: some View {
        HStack(spacing: 8) {
            hintPill
            Spacer(minLength: 4)
            removeAdsControl
            if game.status != .playing {
                ShareLink(item: game.shareText) { iconLabel("square.and.arrow.up") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("share-button")
                    .accessibilityLabel(Text("Share"))
            }
            iconButton("trophy.fill") {
                if gameCenter.isAuthenticated { showLeaderboard = true }
                else { gameCenter.authenticate() }
            }
            .accessibilityIdentifier("leaderboard-button")
            .accessibilityLabel(Text("Leaderboard"))
            iconButton("gearshape.fill") { showSettings = true }
                .accessibilityIdentifier("settings-button")
                .accessibilityLabel(Text("Settings"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glass(cornerRadius: 22)
    }

    private var hintPill: some View {
        Button {
            if game.hintsRemaining > 0 {
                game.useHint()
                keyboardFocused = true
            } else {
                showHintStore = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.warmYellow)
                Text("\(game.hintsRemaining)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.warmYellow.opacity(game.hintsRemaining > 0 ? 0.20 : 0.10),
                       in: Capsule())
            .overlay(Capsule().strokeBorder(Color.warmYellow.opacity(0.5), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if game.hintsRemaining == 0 {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.neonGreen)
                        .background(Circle().fill(.black))
                        .offset(x: 3, y: -3)
                }
            }
            .shadow(color: .warmYellow.opacity(game.hintsRemaining > 0 ? 0.45 : 0.2), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(game.status != .playing)
        .accessibilityIdentifier("hint-pill")
        .accessibilityLabel("Hints: \(game.hintsRemaining)")
    }

    @ViewBuilder
    private var removeAdsControl: some View {
        if isAdFree {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                Text("PRO").font(.system(size: 12, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Palette.proGradient, in: Capsule())
            .shadow(color: .auroraMagenta.opacity(0.5), radius: 8)
        } else {
            Button {
                Task { await store.purchaseRemoveAds() }
            } label: {
                HStack(spacing: 5) {
                    if store.state == .purchasing {
                        ProgressView().controlSize(.mini).tint(.white)
                    } else {
                        Image(systemName: "nosign").font(.system(size: 12, weight: .bold))
                    }
                    Text("Remove Ads")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.glassStrokeGradient, lineWidth: 1))
                .shadow(color: .auroraPurple.opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(store.state == .purchasing)
        }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { iconLabel(systemName) }
            .buttonStyle(.plain)
    }

    private func iconLabel(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Palette.glassStrokeGradient, lineWidth: 1))
    }

    // MARK: - Mode

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(GameMode.allCases) { mode in
                let selected = mode == game.mode
                Button {
                    game.changeMode(mode)
                    keyboardFocused = true
                } label: {
                    modeLabel(mode)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? Color.black.opacity(0.85) : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if selected { Capsule().fill(Color.neonGreen) }
                        }
                }
                .buttonStyle(.plain)
                .disabled(selected || game.isRevealing)
                .accessibilityIdentifier("mode-\(mode.rawValue)")
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassStrokeGradient, lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: game.mode)
    }

    private func modeLabel(_ mode: GameMode) -> Text {
        switch mode {
        case .daily:
            return game.puzzleNumber.map { Text("Daily #\($0)") } ?? Text("Daily")
        case .free:
            return Text("Free play")
        }
    }

    // MARK: - Title

    private var titleView: some View {
        Text(title)
            .font(.system(size: 36, weight: .black, design: .rounded))
            .tracking(1)
            .foregroundStyle(
                LinearGradient(colors: [.white, .neonGreen, .auroraTeal],
                               startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: .neonGreen.opacity(0.9), radius: 10)
            .shadow(color: .auroraTeal.opacity(0.7), radius: 20)
            .shadow(color: .auroraPurple.opacity(0.55), radius: 30)
            .accessibilityIdentifier("game-title")
    }

    // MARK: - Toast

    @ViewBuilder
    private var toast: some View {
        if let message = game.toast {
            Text(message)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .glass(cornerRadius: 30)
                .padding(.top, 64)
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(2)
        }
    }

    // MARK: - Game over

    @ViewBuilder
    private var gameOverOverlay: some View {
        if game.showGameOver {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.indigoDeep.opacity(0.45))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        // The finished daily board stays visible behind the overlay.
                        if game.mode == .daily {
                            withAnimation { game.showGameOver = false }
                        }
                    }
                GameOverView(
                    didWin: game.status == .won,
                    targetWord: game.targetWord,
                    puzzleNumber: game.puzzleNumber,
                    shareText: game.shareText,
                    onPlayAgain: {
                        if game.mode == .daily { game.changeMode(.free) } else { game.newGame() }
                        keyboardFocused = true
                    }
                )
            }
            .zIndex(3)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(GameViewModel(targetWord: "FOCUS"))
        .environmentObject(StoreManager())
        .environmentObject(AdManager())
        .environmentObject(GameCenterManager.shared)
}
