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
    /// Sync bookkeeping (seconds since 1970): last local change, last reset.
    static let updatedAt    = "statsUpdatedAt"
    static let resetAt      = "statsResetAt"
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
        defaults.set(Date().timeIntervalSince1970, forKey: StatsKey.updatedAt)
        CloudStatsSync.shared.push()
    }

    static func reset() {
        [StatsKey.gamesPlayed, StatsKey.gamesWon, StatsKey.currentStreak, StatsKey.maxStreak]
            .forEach { defaults.removeObject(forKey: $0) }
        // Stamping the reset makes other devices drop their older stats
        // instead of merging them back in.
        let now = Date().timeIntervalSince1970
        defaults.set(now, forKey: StatsKey.updatedAt)
        defaults.set(now, forKey: StatsKey.resetAt)
        CloudStatsSync.shared.push()
    }

    static var snapshot: StatsSnapshot {
        StatsSnapshot(
            gamesPlayed: defaults.integer(forKey: StatsKey.gamesPlayed),
            gamesWon: defaults.integer(forKey: StatsKey.gamesWon),
            currentStreak: defaults.integer(forKey: StatsKey.currentStreak),
            maxStreak: defaults.integer(forKey: StatsKey.maxStreak),
            updatedAt: defaults.double(forKey: StatsKey.updatedAt),
            resetAt: defaults.double(forKey: StatsKey.resetAt))
    }

    /// Writes merged stats back; views observing the keys via `@AppStorage` refresh.
    static func apply(_ snapshot: StatsSnapshot) {
        defaults.set(snapshot.gamesPlayed, forKey: StatsKey.gamesPlayed)
        defaults.set(snapshot.gamesWon, forKey: StatsKey.gamesWon)
        defaults.set(snapshot.currentStreak, forKey: StatsKey.currentStreak)
        defaults.set(snapshot.maxStreak, forKey: StatsKey.maxStreak)
        defaults.set(snapshot.updatedAt, forKey: StatsKey.updatedAt)
        defaults.set(snapshot.resetAt, forKey: StatsKey.resetAt)
    }

    static func winPercentage(played: Int, won: Int) -> Int {
        guard played > 0 else { return 0 }
        return Int((Double(won) / Double(played) * 100).rounded())
    }
}

// MARK: - Cloud sync

/// Stats plus the timestamps needed to merge two devices' copies.
/// Same rules as the Android app's `StatsRecord`.
struct StatsSnapshot: Equatable, Codable {
    var gamesPlayed = 0
    var gamesWon = 0
    var currentStreak = 0
    var maxStreak = 0
    var updatedAt: TimeInterval = 0
    var resetAt: TimeInterval = 0

    /// Counts and best streak take the larger value; the current streak comes
    /// from whichever copy changed last. A copy last changed before the newest
    /// reset is stale and dropped, so a reset isn't undone by another device.
    func merged(with other: StatsSnapshot) -> StatsSnapshot {
        let reset = max(resetAt, other.resetAt)
        let live = [self, other].filter { $0.updatedAt >= reset }
        guard let newer = live.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return StatsSnapshot(updatedAt: reset, resetAt: reset)
        }
        guard live.count == 2 else {
            var only = newer
            only.resetAt = reset
            return only
        }
        let played = max(gamesPlayed, other.gamesPlayed)
        return StatsSnapshot(
            gamesPlayed: played,
            gamesWon: min(max(gamesWon, other.gamesWon), played),
            currentStreak: newer.currentStreak,
            maxStreak: max(maxStreak, other.maxStreak, newer.currentStreak),
            updatedAt: newer.updatedAt,
            resetAt: reset)
    }
}

/// Mirrors stats and streaks through the iCloud key-value store, so they follow
/// the player across their devices and reinstalls. A safe no-op when iCloud is
/// signed out: the store then simply stays local.
final class CloudStatsSync {

    static let shared = CloudStatsSync()
    private static let cloudKey = "stats.v1"

    private let store = NSUbiquitousKeyValueStore.default
    private var started = false

    private init() {}

    /// Pulls the cloud copy now and on every change from another device.
    func start() {
        guard !started, ProcessInfo.processInfo.environment["UITESTS"] != "1" else { return }
        started = true
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { [weak self] _ in self?.push() }
        store.synchronize()
        push()
    }

    /// Merges local and cloud stats, then saves the result to both.
    func push() {
        guard started else { return }
        let local = StatsStore.snapshot
        let merged = cloudSnapshot().map { local.merged(with: $0) } ?? local
        if merged != local {
            StatsStore.apply(merged)
            Task { @MainActor in GameCenterManager.shared.submitStats() }
        }
        if let data = try? JSONEncoder().encode(merged) {
            store.set(data, forKey: Self.cloudKey)
        }
    }

    private func cloudSnapshot() -> StatsSnapshot? {
        store.data(forKey: Self.cloudKey).flatMap { try? JSONDecoder().decode(StatsSnapshot.self, from: $0) }
    }
}
