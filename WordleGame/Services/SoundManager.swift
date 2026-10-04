//
//  SoundManager.swift
//  WordleGame
//
//  Minimal SFX using system sounds (no bundled audio assets required, so the
//  project stays dependency-free). Swap `play` for AVAudioPlayer + your own
//  files if you want custom sounds.
//

import AudioToolbox
import UIKit

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    var isEnabled = true

    enum Effect {
        case key, win, lose, invalid

        var systemSoundID: SystemSoundID {
            switch self {
            case .key:     return 1104   // Tock
            case .win:     return 1025   // Fanfare-ish
            case .lose:    return 1053
            case .invalid: return 1053
            }
        }
    }

    func play(_ effect: Effect) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }
}
