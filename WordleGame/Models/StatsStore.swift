//
//  StatsStore.swift
//  WordleGame
//
//  Lightweight persistence for game statistics. Views observe the same keys
//  through `@AppStorage`, so the UI updates automatically after `record(win:)`.
//

import Foundation

enum StatsKey {
    static let gamesPlayed  = "gamesPlayed"
    static let gamesWon     = "gamesWon"
    static let currentStreak = "currentStreak"
    static let maxStreak    = "maxStreak"
}

enum StatsStore {

    private static var defaults: UserDefaults { .standard }

    static func record(win: Bool) {
        let played = defaults.integer(forKey: StatsKey.gamesPlayed) + 1
        defaults.set(played, forKey: StatsKey.gamesPlayed)

        if win {
            defaults.set(defaults.integer(forKey: StatsKey.gamesWon) + 1, forKey: StatsKey.gamesWon)
            let streak = defaults.integer(forKey: StatsKey.currentStreak) + 1
            defaults.set(streak, forKey: StatsKey.currentStreak)
            defaults.set(max(streak, defaults.integer(forKey: StatsKey.maxStreak)), forKey: StatsKey.maxStreak)
        } else {
            defaults.set(0, forKey: StatsKey.currentStreak)
        }
    }

    static func reset() {
        [StatsKey.gamesPlayed, StatsKey.gamesWon, StatsKey.currentStreak, StatsKey.maxStreak]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    static func winPercentage(played: Int, won: Int) -> Int {
        guard played > 0 else { return 0 }
        return Int((Double(won) / Double(played) * 100).rounded())
    }
}
