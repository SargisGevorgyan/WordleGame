//
//  GameCenterManager.swift
//  WordleGame
//
//  Game Center: authentication + leaderboard score submission.
//
//  Setup for release (see RELEASE.md):
//   • Enable the Game Center capability (already in WordleGame.entitlements).
//   • In App Store Connect create two leaderboards with the IDs below
//     (Integer, "High to Low"), and localize their names.
//

import GameKit
import SwiftUI

@MainActor
final class GameCenterManager: ObservableObject {

    static let shared = GameCenterManager()

    /// 🔧 Replace with your App Store Connect leaderboard IDs.
    static let winsLeaderboardID   = "com.sargisgevorgyan.wordlegame.wins"
    static let streakLeaderboardID = "com.sargisgevorgyan.wordlegame.beststreak"

    enum Status: Equatable {
        case unknown        // not attempted yet
        case authenticated
        case signedOut      // user can retry sign-in
        case unavailable    // app not configured on App Store Connect yet
    }

    @Published private(set) var status: Status = .unknown
    var isAuthenticated: Bool { status == .authenticated }

    private init() {}

    // MARK: - Authentication

    func authenticate() {
        // Skip in UI tests — no Game Center session available.
        if ProcessInfo.processInfo.environment["UITESTS"] == "1" { return }

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.rootViewController?.present(viewController, animated: true)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self.status = .authenticated
                    self.submitStats()
                } else if let error = error as NSError? {
                    // Code 15 / server 5019 = the bundle id isn't registered with
                    // Game Center yet (no App Store Connect app record, or Game
                    // Center not enabled for a version). Nothing the app can fix.
                    let notConfigured = error.code == GKError.Code.gameUnrecognized.rawValue
                        || (error.userInfo["GKServerStatusCode"] as? Int) == 5019
                    self.status = notConfigured ? .unavailable : .signedOut
                    print("[GameCenter] Sign-in unavailable: \(error.localizedDescription)")
                } else {
                    self.status = .signedOut
                }
            }
        }
    }

    // MARK: - Leaderboards

    /// Push the current persisted stats to Game Center. Safe to call anytime.
    func submitStats() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let wins = UserDefaults.standard.integer(forKey: StatsKey.gamesWon)
        let bestStreak = UserDefaults.standard.integer(forKey: StatsKey.maxStreak)

        submit(wins, to: Self.winsLeaderboardID)
        submit(bestStreak, to: Self.streakLeaderboardID)
    }

    private func submit(_ score: Int, to leaderboardID: String) {
        GKLeaderboard.submitScore(
            score, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID]
        ) { error in
            if let error {
                print("[GameCenter] Score submit (\(leaderboardID)) failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
