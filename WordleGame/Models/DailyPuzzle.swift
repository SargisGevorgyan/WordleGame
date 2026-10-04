//
//  DailyPuzzle.swift
//  WordleGame
//
//  The word of the day and the shareable emoji grid. Mirrors the Android
//  `DailyPuzzle` exactly, so players on both apps get the same word on the
//  same (local) date:
//
//  - day = days from `epoch` to the player's local date; puzzle number = day + 1.
//  - The language's playable words are shuffled once with a fixed-seed
//    SplitMix64 Fisher–Yates, and day `d` plays entry `d mod count`. No word
//    repeats until the whole list has been used.
//
//  Editing a word list reshuffles the order, so ship word changes to both apps together.
//

import Foundation

/// Free play picks a random word; daily gives everyone the same word each day.
enum GameMode: String, CaseIterable, Identifiable {
    case daily
    case free

    var id: String { rawValue }

    static let storageKey = "gameMode"

    /// The stored choice; new players start on the daily word.
    static var current: GameMode {
        UserDefaults.standard.string(forKey: storageKey).flatMap(GameMode.init(rawValue:)) ?? .daily
    }
}

enum DailyPuzzle {

    /// Day 0 (puzzle #1): 2026-10-04.
    static let epoch = DateComponents(year: 2026, month: 10, day: 4)
    static let seed: UInt64 = 0x5752444C45   // "WRDLE"

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Days from `epoch` to `date`'s calendar day in `calendar` (the player's time zone).
    static func dayNumber(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        // Read the date in the Gregorian calendar (the player may use another one) in their time zone.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let local = gregorian.dateComponents([.year, .month, .day], from: date)
        let calendarUTC = utcCalendar
        guard let day = calendarUTC.date(from: local), let start = calendarUTC.date(from: epoch) else { return 0 }
        return calendarUTC.dateComponents([.day], from: start, to: day).day ?? 0
    }

    static func puzzleNumber(day: Int) -> Int { day + 1 }

    /// When the next word unlocks (local midnight).
    static func nextWordDate(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }

    static func word(for language: GameLanguage, day: Int) -> String {
        let words = language.words
        let index = ((day % words.count) + words.count) % words.count
        return words[order(count: words.count)[index]].uppercased()
    }

    /// Fixed shuffle of `0..<count`.
    static func order(count: Int) -> [Int] {
        var indices = Array(0..<count)
        var random = SplitMix64(state: seed)
        var i = count - 1
        while i > 0 {
            let j = Int(random.next() % UInt64(i + 1))
            indices.swapAt(i, j)
            i -= 1
        }
        return indices
    }

    struct SplitMix64 {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Saved progress

    /// Saved as "<day>|GUESS,GUESS" per language; another day's progress is ignored.
    private static func key(_ language: GameLanguage) -> String { "daily.\(language.bcp47)" }

    static func savedGuesses(language: GameLanguage, day: Int) -> [String] {
        guard let saved = UserDefaults.standard.string(forKey: key(language)) else { return [] }
        let parts = saved.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == String(day) else { return [] }
        return parts[1].split(separator: ",").map(String.init)
    }

    static func save(guesses: [String], language: GameLanguage, day: Int) {
        UserDefaults.standard.set("\(day)|" + guesses.joined(separator: ","), forKey: key(language))
    }
}

/// The emoji grid players paste into chats.
enum ShareCard {
    static func text(title: String, puzzleNumber: Int?, rows: [[LetterEvaluation]], didWin: Bool) -> String {
        let score = didWin ? String(rows.count) : "X"
        let header = ([title] + (puzzleNumber.map { ["#\($0)"] } ?? [])).joined(separator: " ")
        let grid = rows.map { row in
            row.map { evaluation -> String in
                switch evaluation {
                case .correct: return "🟩"
                case .present: return "🟨"
                default:       return "⬛"
                }
            }.joined()
        }.joined(separator: "\n")
        return "\(header) \(score)/\(GameConstants.maxGuesses)\n\n\(grid)"
    }
}
