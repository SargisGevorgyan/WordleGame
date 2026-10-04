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

    /// Fill colour for a grid tile / keyboard key in this state.
    var fillColor: Color {
        switch self {
        case .empty:   return Color.wordleTileEmpty
        case .tbd:     return Color.wordleTileEmpty
        case .correct: return Color.wordleGreen
        case .present: return Color.wordleYellow
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
    /// Timed mode: 3 minutes per game.
    static let timeLimitSeconds = 180
}

/// Why a guess breaks Hard mode. `position` is 0-based.
enum HardModeViolation: Equatable {
    case missingCorrect(position: Int, token: String)
    case missingPresent(token: String)
}

/// Hard mode: every revealed hint must be used in later guesses. A green letter
/// stays in its spot; a yellow (or green) letter must appear somewhere, as many
/// times as it was revealed in a single row. Mirrors Android's `HardMode`.
enum HardMode {
    static func violation(board: [[Tile]], row: Int, guess: [String]) -> HardModeViolation? {
        let revealed = board.prefix(row)
        for tiles in revealed {
            for (index, tile) in tiles.enumerated() {
                guard let letter = tile.letter, tile.evaluation == .correct else { continue }
                if index >= guess.count || guess[index] != letter {
                    return .missingCorrect(position: index, token: letter)
                }
            }
        }
        for tiles in revealed {
            var required: [String: Int] = [:]
            var order: [String] = []
            for tile in tiles where tile.evaluation == .correct || tile.evaluation == .present {
                guard let letter = tile.letter else { continue }
                if required[letter] == nil { order.append(letter) }
                required[letter, default: 0] += 1
            }
            for token in order where guess.filter({ $0 == token }).count < required[token]! {
                return .missingPresent(token: token)
            }
        }
        return nil
    }
}
