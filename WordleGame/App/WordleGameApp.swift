//
//  WordleGameApp.swift
//  WordleGame
//
//  A Wordle-style word game built with pure SwiftUI (MVVM).
//

import SwiftUI

@main
struct WordleGameApp: App {

    // Single source of truth for the game, injected into the environment.
    @StateObject private var game = GameViewModel()

    // Monetization managers. Both are safe no-ops when their SDKs / StoreKit
    // products are unavailable, so the app always runs.
    @StateObject private var store = StoreManager()
    @StateObject private var ads = AdManager()

    @StateObject private var gameCenter = GameCenterManager.shared

    @Environment(\.scenePhase) private var scenePhase

    // Animated intro over the game; skipped in UI tests so they start at once.
    @State private var showSplash = ProcessInfo.processInfo.environment["UITESTS"] != "1"

    init() {
        AdManager.bootstrap()

        #if DEBUG
        // Deterministic starting state for UI tests.
        if ProcessInfo.processInfo.environment["UITESTS"] == "1" {
            let env = ProcessInfo.processInfo.environment
            UserDefaults.standard.set(env["UITEST_LANG"] ?? GameLanguage.english.rawValue,
                                      forKey: GameLanguage.storageKey)
            UserDefaults.standard.set(Int(env["UITEST_HINTS"] ?? "3") ?? 3,
                                      forKey: GameViewModel.hintsKey)
            return
        }
        #endif

        // First launch: seed the language from the device locale so the stored
        // value, the view model and the Settings selector all agree.
        if !GameLanguage.hasExplicitChoice {
            UserDefaults.standard.set(GameLanguage.systemDefault.rawValue,
                                      forKey: GameLanguage.storageKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(game)
                    .environmentObject(store)
                    .environmentObject(ads)
                    .environmentObject(gameCenter)
                    .tint(Color.wordleAccent)
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { TrackingAuthorization.requestIfNeeded() }
                    }

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
