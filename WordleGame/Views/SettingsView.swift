//
//  SettingsView.swift
//  WordleGame
//
//  Statistics + monetization controls (Remove Ads / Restore Purchases).
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var gameCenter: GameCenterManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("isAdFree") private var isAdFree = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(LetterEvaluation.highContrastKey) private var highContrast = false
    @AppStorage(GameLanguage.storageKey) private var languageRaw = GameLanguage.systemDefault.rawValue

    @State private var pendingLanguage: GameLanguage?
    @State private var showLeaderboard = false

    private var selectedLanguage: GameLanguage {
        GameLanguage(rawValue: languageRaw) ?? .systemDefault
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ForEach(GameLanguage.allCases) { language in
                            LanguageCard(language: language,
                                         isSelected: selectedLanguage == language) {
                                select(language)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Word Language")
                } footer: {
                    Text("Auto-selected from your device (\(GameLanguage.systemDefault.displayName)) on first launch. Switching starts a new game.")
                }

                Section("Statistics") {
                    StatsView()
                        .padding(.vertical, 8)
                    Button("Reset Statistics", role: .destructive) {
                        StatsStore.reset()
                    }
                }

                Section("Game Center") {
                    switch gameCenter.status {
                    case .authenticated:
                        Button { showLeaderboard = true } label: {
                            Label("Leaderboards", systemImage: "trophy.fill")
                        }
                    case .unavailable:
                        Label("Game Center isn't set up for this build yet.", systemImage: "trophy")
                            .foregroundStyle(.secondary)
                    case .unknown, .signedOut:
                        Button { gameCenter.authenticate() } label: {
                            Label("Sign in to Game Center", systemImage: "trophy.fill")
                        }
                    }
                }

                Section("Remove Ads") {
                    if isAdFree {
                        Label("Ads removed. Thank you!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.wordleGreen)
                    } else {
                        Button {
                            Task { await store.purchaseRemoveAds() }
                        } label: {
                            HStack {
                                Text("Remove Ads")
                                Spacer()
                                Text(store.removeAdsDisplayPrice).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.state == .purchasing)

                        Button("Restore Purchases") {
                            Task { await store.restorePurchases() }
                        }
                    }

                    if case .failed(let message) = store.state {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Sound & Haptics") {
                    Toggle("Sound effects", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { _, enabled in
                            SoundManager.shared.isEnabled = enabled
                        }
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section {
                    Toggle("High contrast colors", isOn: $highContrast)
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Color-blind friendly: orange = right spot, blue = wrong spot.")
                }

                Section {
                    Text("How to play: guess the 5-letter word in 6 tries. Green = right spot, Yellow = wrong spot, Gray = not in the word.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Start a new game in \(pendingLanguage?.displayName ?? "")?",
                isPresented: Binding(get: { pendingLanguage != nil },
                                     set: { if !$0 { pendingLanguage = nil } }),
                titleVisibility: .visible
            ) {
                Button("Switch & restart", role: .destructive) {
                    if let language = pendingLanguage { languageRaw = language.rawValue }
                    pendingLanguage = nil
                }
                Button("Cancel", role: .cancel) { pendingLanguage = nil }
            } message: {
                Text("Your current game will be lost.")
            }
            .sheet(isPresented: $showLeaderboard) {
                GameCenterView(leaderboardID: GameCenterManager.streakLeaderboardID)
                    .ignoresSafeArea()
            }
        }
    }

    private func select(_ language: GameLanguage) {
        guard language != selectedLanguage else { return }
        if game.languageSwitchLosesGame {
            pendingLanguage = language
        } else {
            languageRaw = language.rawValue
        }
    }
}

// MARK: - Language card

private struct LanguageCard: View {
    let language: GameLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Text(verbatim: language.autonym)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.neonGreen : .secondary)
                }
                Text(verbatim: language.sampleTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.neonGreen, .auroraTeal],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: language.localizedName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.neonGreen.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.neonGreen.opacity(0.8) : Color.white.opacity(0.12),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.neonGreen.opacity(0.35) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityIdentifier("lang-\(language.rawValue)")
        .accessibilityLabel(language.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
