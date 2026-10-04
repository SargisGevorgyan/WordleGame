//
//  WordBank.swift
//  WordleGame
//
//  Built-in word lists so the game works completely offline.
//  The words live in `shared/words/words_<lang>.txt` at the repo root — the
//  single source of truth shared with the Android app — and are bundled as
//  resources. All words are stored / compared in UPPERCASE (works for English
//  and Armenian). Access them through `GameLanguage` rather than directly.
//

import Foundation

enum WordBank {

    static let english: [String]  = load("words_en")
    static let armenian: [String] = load("words_hy")

    // MARK: - Lookup sets

    static let englishSet: Set<String> = Set(english)
    static let armenianSet: Set<String> = Set(armenian)
    // The list actually used for Armenian play (tokenised to 5 letters, ու = 1)
    // lives in `GameLanguage.armenianPlayableWords`.

    // MARK: - Loading

    /// Parses a word file: one word per line; blank lines and `#` comments are ignored.
    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0.uppercased() }
    }

    private static func load(_ name: String) -> [String] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing word list \(name).txt — is shared/words in the Copy Bundle Resources phase?")
            return []
        }
        return parse(text)
    }

    private final class BundleToken {}
}

// MARK: - Meanings

/// English meanings for words, parsed from the shared `shared/words/glosses_<code>.tsv`
/// (also read by the Android app). Used for the post-game meaning and the
/// Armenian word of the day.
struct Glossary {
    let entries: [(word: String, gloss: String)]
    private let map: [String: String]

    init(entries: [(word: String, gloss: String)]) {
        self.entries = entries
        self.map = Dictionary(entries.map { ($0.word, $0.gloss) }, uniquingKeysWith: { first, _ in first })
    }

    static let armenian: Glossary = load("glosses_hy")

    func meaning(_ word: String) -> String? { map[word.uppercased()] }

    /// The word of the day for `date`, chosen from the glossed words in `playable`.
    /// Same day → same word on iOS and Android.
    func wordOfTheDay(on date: Date = .now, playable: Set<String>) -> (word: String, gloss: String)? {
        let candidates = entries.filter { playable.contains($0.word) }
        guard !candidates.isEmpty else { return nil }
        return candidates[Self.dayIndex(Self.epochDay(for: date), count: candidates.count)]
    }

    /// Days since 1970-01-01 for the player's local calendar date
    /// (Android: `LocalDate.now().toEpochDay()`).
    static func epochDay(for date: Date, timeZone: TimeZone = .current) -> Int {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let components = local.dateComponents([.year, .month, .day], from: date)
        guard let midnight = utc.date(from: components) else { return 0 }
        return Int((midnight.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Spreads consecutive days across the list (7919 is prime).
    static func dayIndex(_ epochDay: Int, count: Int) -> Int {
        ((epochDay * 7919) % count + count) % count
    }

    /// `WORD<TAB>gloss` per line; blank lines and `#` comments are ignored.
    static func parse(_ text: String) -> Glossary {
        let entries: [(word: String, gloss: String)] = text.split(whereSeparator: \.isNewline).compactMap { raw -> (word: String, gloss: String)? in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                  let tab = line.firstIndex(of: "\t") else { return nil }
            let word = line[..<tab].trimmingCharacters(in: .whitespaces).uppercased()
            let gloss = line[line.index(after: tab)...].trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty, !gloss.isEmpty else { return nil }
            return (word, gloss)
        }
        return Glossary(entries: entries)
    }

    private static func load(_ name: String) -> Glossary {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing \(name).tsv — is shared/words in the Copy Bundle Resources phase?")
            return Glossary(entries: [])
        }
        return parse(text)
    }

    private final class BundleToken {}
}
