//
//  GameViewModel.swift
//  WordleGame
//
//  The single ObservableObject that drives the board, keyboard and game state.
//

import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var board: [[Tile]]
    @Published private(set) var currentRow = 0
    @Published private(set) var currentColumn = 0
    @Published private(set) var status: GameStatus = .playing
    /// Keyed by board *token* ("A", or the Armenian "ՈՒ" digraph).
    @Published private(set) var keyboardHints: [String: LetterEvaluation] = [:]
    @Published private(set) var isRevealing = false
    @Published private(set) var hintsRemaining = (UserDefaults.standard.object(forKey: "hintsRemaining") as? Int) ?? 3

    static let hintsKey = "hintsRemaining"
    static let maxHints = 99          // upper bound (purchases can stack)
    static let freeHintCeiling = 5    // the win reward won't push above this

    /// Wordy Pro: hints are free and never run out (set from `StoreManager.isPro`).
    @Published var hasUnlimitedHints = UserDefaults.standard.bool(forKey: StoreManager.isProKey)

    /// Bumping this value makes the current row play its shake animation.
    @Published var shakeToken = 0
    /// Transient banner shown for invalid input ("Not in word list", …).
    @Published private(set) var toast: String?
    /// Drives the end-of-game overlay.
    @Published var showGameOver = false

    // MARK: - Config

    @Published private(set) var language: GameLanguage
    private(set) var targetWord: String {
        didSet {
            #if DEBUG
            print("3: targetWord: \(targetWord)")
            #endif
        }
    }
    let revealDuration = 1.7

    /// Identifies the current game, so reveal / game-over timers scheduled for
    /// an earlier game do nothing once a new one has started.
    private var gameID = UUID()
    /// The submitted guess whose reveal animation is still running.
    private var pendingReveal: (row: Int, guess: String, evaluations: [LetterEvaluation])?

    /// Callback fired once per finished game (win or lose). Used for ad cadence.
    var onRoundFinished: ((_ didWin: Bool) -> Void)?

    /// The active on-screen keyboard layout for this language.
    var keyboardRows: [[String]] { language.keyboardRows }
    var keyboardIsCompact: Bool { language.keyboardIsCompact }

    // MARK: - Init

    init(language: GameLanguage = .current) {
        self.language = language
        #if DEBUG
        let forced = ProcessInfo.processInfo.environment["UITEST_TARGET"]
        self.targetWord = (forced?.isEmpty == false ? forced! : language.randomWord()).uppercased()
        #else
        self.targetWord = language.randomWord()
        #endif
        self.board = Self.makeEmptyBoard()
        #if DEBUG
        print("1: targetWorld: \(targetWord)")
        #endif
    }

    /// Test seam: start with a known target.
    init(targetWord: String, language: GameLanguage = .english) {
        self.language = language
        self.targetWord = targetWord.uppercased()
        self.board = Self.makeEmptyBoard()
        #if DEBUG
        print("2: targetWorld: \(targetWord)")
        #endif
    }

    private static func makeEmptyBoard() -> [[Tile]] {
        // Build each Tile individually — `Array(repeating:)` would share one
        // Tile value (and its `id`) across every cell, which breaks ForEach.
        (0..<GameConstants.maxGuesses).map { _ in
            (0..<GameConstants.wordLength).map { _ in Tile(letter: nil) }
        }
    }

    // MARK: - Derived

    /// Tokens currently entered in the active row.
    var currentTokens: [String] {
        board[safe: currentRow]?.compactMap { $0.letter } ?? []
    }

    /// The active row as a plain string (tokens concatenated).
    var currentGuess: String { currentTokens.joined() }

    /// True once the player has made progress that a language switch would discard.
    var isInProgress: Bool {
        status == .playing && (currentRow > 0 || !currentTokens.isEmpty)
    }

    // MARK: - Input

    /// Entry point for both keyboards: a key sends its token string.
    func enterKey(_ token: String) {
        if token.count == 1, let character = token.first {
            insert(character)
        } else {
            insertToken(token)
        }
    }

    func insert(_ character: Character) {
        guard status == .playing, !isRevealing else { return }
        guard let letter = language.normalize(character) else { return }

        // Armenian ու digraph: typing Ւ right after Ո merges them into one tile.
        if language == .armenian, letter == "Ւ", currentColumn > 0,
           board[currentRow][currentColumn - 1].letter == "Ո",
           board[currentRow][currentColumn - 1].evaluation == .tbd {
            board[currentRow][currentColumn - 1].letter = "ՈՒ"
            Haptics.shared.tap()
            SoundManager.shared.play(.key)
            return
        }

        insertToken(String(letter))
    }

    /// Places a whole token in the next free tile.
    func insertToken(_ token: String) {
        guard status == .playing, !isRevealing else { return }
        guard currentColumn < GameConstants.wordLength else { return }

        board[currentRow][currentColumn].letter = token.uppercased()
        board[currentRow][currentColumn].evaluation = .tbd
        currentColumn += 1
        Haptics.shared.tap()
        SoundManager.shared.play(.key)
    }

    /// Reveal the correct letter for the next empty slot in the current row.
    /// Returns `false` when there were no hints to spend (the UI then offers the
    /// hint store).
    @discardableResult
    func useHint() -> Bool {
        guard status == .playing, !isRevealing else { return true }
        guard hasUnlimitedHints || hintsRemaining > 0 else { return false }
        guard currentColumn < GameConstants.wordLength else { return true }
        let targetTokens = language.tokenize(targetWord)
        guard currentColumn < targetTokens.count else { return true }

        if !hasUnlimitedHints { setHints(hintsRemaining - 1) }
        Haptics.shared.notify(.success)
        flashToast("Hint revealed")
        insertToken(targetTokens[currentColumn])
        return true
    }

    /// Add hints earned from a rewarded ad or bought via IAP.
    func addHints(_ count: Int) {
        guard count > 0 else { return }
        setHints(hintsRemaining + count)
        Haptics.shared.notify(.success)
        flashToast(count == 1 ? "+1 hint" : "+\(count) hints")
    }

    private func setHints(_ value: Int) {
        let clamped = max(0, min(Self.maxHints, value))
        hintsRemaining = clamped
        UserDefaults.standard.set(clamped, forKey: Self.hintsKey)
    }

    func deleteLetter() {
        guard status == .playing, !isRevealing, currentColumn > 0 else { return }
        currentColumn -= 1
        board[currentRow][currentColumn].letter = nil
        board[currentRow][currentColumn].evaluation = .empty
        Haptics.shared.tap(intensity: 0.5)
    }

    func submit() {
        guard status == .playing, !isRevealing else { return }

        guard currentColumn == GameConstants.wordLength else {
            flashToast("Not enough letters")
            shake()
            return
        }

        let guessTokens = currentTokens
        let guess = guessTokens.joined()
        guard language.isValidGuess(guess) else {
            flashToast("Not in word list")
            shake()
            return
        }

        let evaluations = Self.evaluate(guessTokens: guessTokens,
                                       targetTokens: language.tokenize(targetWord))
        for (index, evaluation) in evaluations.enumerated() where index < board[currentRow].count {
            board[currentRow][index].evaluation = evaluation
        }

        isRevealing = true
        Haptics.shared.tap(intensity: 0.7)

        pendingReveal = (currentRow, guess, evaluations)
        let id = gameID
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDuration) { [weak self] in
            guard let self, self.gameID == id, let pending = self.pendingReveal else { return }
            self.finishReveal(row: pending.row, guess: pending.guess, evaluations: pending.evaluations)
        }
    }

    // MARK: - Reveal / resolution

    private func finishReveal(row: Int, guess: String, evaluations: [LetterEvaluation]) {
        pendingReveal = nil
        mergeKeyboardHints(tokens: language.tokenize(guess), evaluations: evaluations)
        isRevealing = false

        if guess == targetWord {
            status = .won
            StatsStore.record(win: true)
            if hintsRemaining < Self.freeHintCeiling {
                setHints(hintsRemaining + 1)    // reward a hint for winning
            }
            Haptics.shared.notify(.success)
            SoundManager.shared.play(.win)
            endGame()
        } else if row == GameConstants.maxGuesses - 1 {
            status = .lost
            StatsStore.record(win: false)
            Haptics.shared.notify(.error)
            SoundManager.shared.play(.lose)
            endGame()
        } else {
            currentRow += 1
            currentColumn = 0
        }
    }

    private func endGame() {
        onRoundFinished?(status == .won)
        let id = gameID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard self?.gameID == id else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                self?.showGameOver = true
            }
        }
    }

    // MARK: - New game

    func newGame() {
        gameID = UUID()
        pendingReveal = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            board = Self.makeEmptyBoard()
            currentRow = 0
            currentColumn = 0
            status = .playing
            keyboardHints = [:]
            isRevealing = false
            toast = nil
            showGameOver = false
        }
        targetWord = language.randomWord()
    }

    /// Switch language and immediately start a fresh game in it.
    /// The game in progress is abandoned, and counts as a loss (so switching
    /// can't be used to protect a streak).
    func changeLanguage(_ newLanguage: GameLanguage) {
        guard newLanguage != language else { return }
        // A guess still flipping counts: resolve it first (it may have won).
        if let pending = pendingReveal {
            finishReveal(row: pending.row, guess: pending.guess, evaluations: pending.evaluations)
        }
        if isInProgress {
            StatsStore.record(win: false)
        }
        language = newLanguage
        newGame()
    }

    // MARK: - Physical keyboard

    /// Handles a hardware-keyboard press coming from SwiftUI's `.onKeyPress`.
    /// Returns `true` when the press was consumed.
    func handleKeyPress(_ press: KeyPress) -> Bool {
        guard let character = press.characters.first else { return false }
        switch character {
        case "\r", "\n", "\u{3}":            // Return / Enter
            submit()
            return true
        case "\u{7F}", "\u{8}":              // Backspace / Delete
            deleteLetter()
            return true
        default:
            guard character.isLetter, press.characters.count == 1 else { return false }
            insert(character)
            return true
        }
    }

    // MARK: - Helpers

    private func shake() {
        Haptics.shared.notify(.warning)
        SoundManager.shared.play(.invalid)
        withAnimation(.default) { shakeToken += 1 }
    }

    private func flashToast(_ key: String.LocalizationValue) {
        let message = String(localized: key)
        withAnimation(.easeInOut(duration: 0.15)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) { self?.toast = nil }
        }
    }

    private func mergeKeyboardHints(tokens: [String], evaluations: [LetterEvaluation]) {
        var updated = keyboardHints
        for (index, token) in tokens.enumerated() where index < evaluations.count {
            let new = evaluations[index]
            if new.rank > (updated[token]?.rank ?? 0) {
                updated[token] = new
            }
        }
        withAnimation(.easeInOut(duration: 0.25)) { keyboardHints = updated }
    }

    /// Classic two-pass Wordle scoring, over tokens, with correct
    /// duplicate handling (a token is one letter — Armenian "ՈՒ" included).
    nonisolated static func evaluate(guessTokens g: [String],
                                     targetTokens t: [String]) -> [LetterEvaluation] {
        let n = min(g.count, t.count)
        var result = [LetterEvaluation](repeating: .absent, count: n)
        var remaining: [String: Int] = [:]
        for token in t { remaining[token, default: 0] += 1 }

        for i in 0..<n where g[i] == t[i] {
            result[i] = .correct
            remaining[g[i]]! -= 1
        }
        for i in 0..<n where result[i] != .correct {
            if let count = remaining[g[i]], count > 0 {
                result[i] = .present
                remaining[g[i]]! -= 1
            }
        }
        return result
    }

    /// Character-level convenience (English / tests).
    nonisolated static func evaluate(guess: String, target: String) -> [LetterEvaluation] {
        evaluate(guessTokens: guess.uppercased().map(String.init),
                 targetTokens: target.uppercased().map(String.init))
    }
}

#if DEBUG
extension GameViewModel {
    /// Synchronously runs the post-reveal resolution (bypasses the animation delay).
    func forceFinishRevealForTesting(guess: String) {
        let evaluations = Self.evaluate(guessTokens: language.tokenize(guess),
                                        targetTokens: language.tokenize(targetWord))
        for (index, evaluation) in evaluations.enumerated() where index < board[currentRow].count {
            board[currentRow][index].evaluation = evaluation
        }
        finishReveal(row: currentRow, guess: guess, evaluations: evaluations)
    }

    func mergeHintsForTesting(guess: String, evaluations: [LetterEvaluation]) {
        mergeKeyboardHints(tokens: language.tokenize(guess), evaluations: evaluations)
    }
}
#endif

// MARK: - Safe indexing

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
