//
//  Haptics.swift
//  WordleGame
//
//  Thin wrapper around UIFeedbackGenerator. Silent when the player turns
//  haptics off in Settings.
//

import UIKit

@MainActor
final class Haptics {
    static let shared = Haptics()

    /// `@AppStorage` key for the Settings toggle (on by default).
    static let enabledKey = "hapticsEnabled"

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        impact.prepare()
        notification.prepare()
    }

    /// Key-press feedback. `intensity` is 0...1.
    func tap(intensity: CGFloat = 0.9) {
        guard isEnabled else { return }
        impact.impactOccurred(intensity: intensity)
        impact.prepare()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notification.notificationOccurred(type)
        notification.prepare()
    }
}
