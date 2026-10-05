//
//  WordMeanings.swift
//  WordleGame
//
//  Short meanings shown after each game. They live next to the word bank in
//  `shared/words/meanings_<lang>.txt` (shared with the Android app), one
//  `WORD|meaning` entry per line. Armenian words carry an English gloss.
//

import Foundation

enum WordMeanings {

    static let english: [String: String]  = load("meanings_en")
    static let armenian: [String: String] = load("meanings_hy")

    /// Parses a meanings file: `WORD|meaning` per line; blank lines and `#`
    /// comments are ignored, and words are matched in UPPERCASE.
    static func parse(_ text: String) -> [String: String] {
        var meanings: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let bar = trimmed.firstIndex(of: "|") else { continue }
            let word = trimmed[..<bar].trimmingCharacters(in: .whitespaces).uppercased()
            let meaning = trimmed[trimmed.index(after: bar)...].trimmingCharacters(in: .whitespaces)
            if !word.isEmpty, !meaning.isEmpty { meanings[word] = meaning }
        }
        return meanings
    }

    private static func load(_ name: String) -> [String: String] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing \(name).txt — is shared/words in the Copy Bundle Resources phase?")
            return [:]
        }
        return parse(text)
    }

    private final class BundleToken {}
}
