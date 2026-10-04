//
//  GameCenterView.swift
//  WordleGame
//
//  SwiftUI wrapper around `GKGameCenterViewController` (leaderboards / dashboard).
//

import GameKit
import SwiftUI

struct GameCenterView: UIViewControllerRepresentable {
    var leaderboardID: String?

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller: GKGameCenterViewController
        if let leaderboardID {
            controller = GKGameCenterViewController(
                leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        } else {
            controller = GKGameCenterViewController(state: .leaderboards)
        }
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            dismiss()
        }
    }
}
