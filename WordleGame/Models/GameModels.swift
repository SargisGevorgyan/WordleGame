//
//  GameModels.swift
//  WordleGame
//
//  Value types that describe the state of a single game.
//

import SwiftUI

/// The evaluation of one letter after a guess is submitted.
enum LetterEvaluation: String, Equatable {
    case empty      // no letter yet
    case tbd        // letter entered, not yet submitted
    case correct    // right letter, right position  -> green
    case present    // right letter, wrong position  -> yellow
    case absent     // letter not in the word        -> gray

    /// `@AppStorage` key for the colour-blind (orange / blue) palette.
    static let highContrastKey = "highContrastColors"

    /// Fill colour for a grid tile / keyboard key in this state.
    func fillColor(highContrast: Bool) -> Color {
        switch self {
        case .empty:   return Color.wordleTileEmpty
        case .tbd:     return Color.wordleTileEmpty
        case .correct: return highContrast ? Color.contrastOrange : Color.wordleGreen
        case .present: return highContrast ? Color.contrastBlue : Color.wordleYellow
        case .absent:  return Color.wordleGray
        }
    }

    var textColor: Color {
        switch self {
        case .empty, .tbd: return Color.wordlePrimaryText
        default:           return .white
        }
    }

    var borderColor: Color {
        switch self {
        case .empty:   return Color.wordleBorderIdle
        case .tbd:     return Color.wordleBorderActive
        default:       return .clear
        }
    }

    /// Stable name for tests / accessibility.
    var name: String { rawValue }

    /// Priority used when merging keyboard hints (green beats yellow beats gray).
    var rank: Int {
        switch self {
        case .correct: return 3
        case .present: return 2
        case .absent:  return 1
        default:       return 0
        }
    }
}

/// A single cell in the 6x5 board.
///
/// `letter` holds a *token* — normally one letter ("Ա"), but the Armenian ու
/// digraph occupies a single tile as `"ՈՒ"`.
struct Tile: Identifiable, Equatable {
    let id = UUID()
    var letter: String?
    var evaluation: LetterEvaluation = .empty

    var displayText: String { letter?.uppercased() ?? "" }
}

/// Overall status of the current game.
enum GameStatus: Equatable {
    case playing
    case won
    case lost
}

enum GameConstants {
    static let maxGuesses = 6
    static let wordLength = 5
}
