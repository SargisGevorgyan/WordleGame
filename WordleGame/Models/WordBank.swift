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
