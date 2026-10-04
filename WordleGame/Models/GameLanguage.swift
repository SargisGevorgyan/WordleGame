//
//  GameLanguage.swift
//  WordleGame
//
//  Language selection for the game. Each language provides its own word list,
//  on-screen keyboard layout and canonical letter casing.
//
//  Persisted via `@AppStorage("gameLanguage")` (stores `rawValue`).
//

import Foundation

enum GameLanguage: String, CaseIterable, Identifiable {
    case english
    case armenian

    var id: String { rawValue }

    /// `@AppStorage` key shared by the views and `GameViewModel`.
    static let storageKey = "gameLanguage"

    /// The language to use when the player hasn't chosen one yet — derived from
    /// the device's preferred languages, then the region. Armenian device or
    /// Armenia region → Armenian; otherwise English.
    static var systemDefault: GameLanguage {
        for identifier in Locale.preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "hy": return .armenian
            case "en": return .english
            default:   continue
            }
        }
        if Locale.current.region?.identifier == "AM" { return .armenian }
        return .english
    }

    /// Currently-selected language: the stored choice, else `systemDefault`.
    static var current: GameLanguage {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(GameLanguage.init(rawValue:)) ?? systemDefault
    }

    /// Whether the player has explicitly picked a language.
    static var hasExplicitChoice: Bool {
        UserDefaults.standard.string(forKey: storageKey) != nil
    }

    /// BCP-47 code for the word-list language.
    var bcp47: String {
        switch self {
        case .english:  return "en"
        case .armenian: return "hy"
        }
    }

    /// The language's name in its own language ("English" / "Հայերեն").
    var autonym: String {
        switch self {
        case .english:  return "English"
        case .armenian: return "Հայերեն"
        }
    }

    /// The language's name in the current UI locale
    /// (EN UI → "English" / "Armenian"; HY UI → "անգլերեն" / "հայերեն").
    var localizedName: String {
        Locale.current.localizedString(forLanguageCode: bcp47)?.localizedCapitalized ?? autonym
    }

    /// Kept for existing call sites — the autonym.
    var displayName: String { autonym }

    /// A short sample rendered on the language card.
    var sampleTitle: String {
        switch self {
        case .english:  return "WORDY"
        case .armenian: return "ԲԱՌ-ԽԱՂ"
        }
    }

    /// The case every guess / target / keyboard hint is normalised to.
    /// English is compared upper-cased too, so the two paths are identical.
    /// Ligatures whose uppercase expands to more than one letter (e.g. `և`)
    /// are rejected rather than crashing `Character(_:)`.
    func normalize(_ character: Character) -> Character? {
        guard character.isLetter else { return nil }
        let uppercased = character.uppercased()
        guard uppercased.count == 1, let upper = uppercased.first else { return nil }
        switch self {
        case .english:
            return upper.isASCII ? upper : nil
        case .armenian:
            // Armenian block only.
            return ("\u{0531}"..."\u{058F}").contains(upper) ? upper : nil
        }
    }

    // MARK: - Tokenising

    /// Splits a word into board *tokens*. English → one token per character.
    /// Armenian → the ու digraph (`Ո` + `Ւ`) collapses into a single `"ՈՒ"`
    /// token, because ու is one letter of the alphabet and occupies one tile.
    func tokenize(_ word: String) -> [String] {
        let chars = Array(word.uppercased())
        switch self {
        case .english:
            return chars.map(String.init)
        case .armenian:
            var tokens: [String] = []
            var i = 0
            while i < chars.count {
                if chars[i] == "Ո", i + 1 < chars.count, chars[i + 1] == "Ւ" {
                    tokens.append("ՈՒ"); i += 2
                } else {
                    tokens.append(String(chars[i])); i += 1
                }
            }
            return tokens
        }
    }

    // MARK: - Words

    /// Words whose **tokenised** length is exactly 5, so they fit the board.
    /// Defensive against typos in the raw `WordBank` lists (wrong-length entries,
    /// and Armenian digraph spellings like `ԱՇՈՒՆ` that are really 4 letters).
    static let englishPlayableWords: [String] =
        WordBank.english.filter { GameLanguage.english.tokenize($0).count == GameConstants.wordLength }
    static let armenianPlayableWords: [String] =
        WordBank.armenian.filter { GameLanguage.armenian.tokenize($0).count == GameConstants.wordLength }

    static let englishPlayableSet: Set<String>  = Set(englishPlayableWords.map { $0.uppercased() })
    static let armenianPlayableSet: Set<String> = Set(armenianPlayableWords.map { $0.uppercased() })

    /// Word list actually used for play.
    var words: [String] {
        switch self {
        case .english:  return Self.englishPlayableWords
        case .armenian: return Self.armenianPlayableWords
        }
    }

    private var wordSet: Set<String> {
        switch self {
        case .english:  return Self.englishPlayableSet
        case .armenian: return Self.armenianPlayableSet
        }
    }

    func randomWord() -> String {
        words.randomElement()!.uppercased()
    }

    func isValidGuess(_ guess: String) -> Bool {
        wordSet.contains(guess.uppercased())
    }

    // MARK: - Keyboard

    /// Rows of key tokens. `"ENTER"` and `"DELETE"` are action keys; everything
    /// else is a single letter.
    var keyboardRows: [[String]] {
        switch self {
        case .english:
            return [
                ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "DELETE"],
                ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
                ["Z", "X", "C", "V", "B", "N", "M", "ENTER"]
            ]
        case .armenian:
            // Armenian phonetic (KDWIN-style) layout — covers the full alphabet.
            return [
                ["Է", "Թ", "Փ", "Ձ", "Ջ", "և", "Ր", "Չ", "Ճ", "Ժ", "DELETE"],
                ["Ք", "Ո", "Ե", "Ռ", "Տ", "Ը", "Ւ", "Ի", "Օ", "Պ", "Խ", "Ծ"],
                ["Ա", "Ս", "Դ", "Ֆ", "Գ", "Հ", "Յ", "Կ", "Լ", "Շ"],
                ["Զ", "Ղ", "Ց", "Վ", "Բ", "Ն", "Մ", "ENTER"]
            ]
        }
    }

    /// True when a row can exceed 10 keys → shrink key metrics.
    var keyboardIsCompact: Bool {
        keyboardRows.contains { $0.count > 10 }
    }
}
