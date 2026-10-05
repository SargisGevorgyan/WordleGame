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

    /// Bumping this value makes the current row play its shake animation.
    @Published var shakeToken = 0
    /// Transient banner shown for invalid input ("Not in word list", …).
    @Published private(set) var toast: String?
    /// Drives the end-of-game overlay.
    @Published var showGameOver = false

    // MARK: - Modes

    static let hardModeKey = "hardMode"
    static let timedModeKey = "timedMode"

    /// Hard mode for the current game (the setting is read when a game starts).
    @Published private(set) var isHardMode = UserDefaults.standard.bool(forKey: GameViewModel.hardModeKey)
    /// Timed mode for the current game.
    @Published private(set) var isTimed = UserDefaults.standard.bool(forKey: GameViewModel.timedModeKey)
    /// Timed mode: seconds left. The clock starts with the first letter.
    @Published private(set) var secondsLeft = GameConstants.timeLimitSeconds
    /// True when a timed game was lost because the clock ran out.
    @Published private(set) var timedOut = false
    private var clockTask: Task<Void, Never>?

    // MARK: - Config

    @Published private(set) var language: GameLanguage
    @Published private(set) var mode: GameMode
    /// Day of the daily game on the board (see `DailyPuzzle.dayNumber`).
    @Published private(set) var dailyDay = DailyPuzzle.dayNumber()
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
    /// The free-play game set aside while the daily game is on screen.
    private var freeGame: Snapshot?
    /// The submitted guess whose reveal animation is still running.
    private var pendingReveal: (row: Int, guess: String, evaluations: [LetterEvaluation])?

    /// Callback fired once per finished game (win or lose). Used for ad cadence.
    var onRoundFinished: ((_ didWin: Bool) -> Void)?

    /// The active on-screen keyboard layout for this language.
    var keyboardRows: [[String]] { language.keyboardRows }
    var keyboardIsCompact: Bool { language.keyboardIsCompact }

    // MARK: - Init

    init(language: GameLanguage = .current, mode: GameMode = .current) {
        self.language = language
        self.mode = mode
        #if DEBUG
        let forced = ProcessInfo.processInfo.environment["UITEST_TARGET"]
        self.targetWord = (forced?.isEmpty == false ? forced! : language.randomWord()).uppercased()
        #else
        self.targetWord = language.randomWord()
        #endif
        self.board = Self.makeEmptyBoard()
        if mode == .daily { loadDaily() }
        #if DEBUG
        print("1: targetWorld: \(targetWord)")
        #endif
    }

    /// Test seam: start a free game with a known target.
    init(targetWord: String, language: GameLanguage = .english) {
        self.language = language
        self.mode = .free
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

    /// Whether switching language now would forfeit a free-play game (the daily one is saved).
    var languageSwitchLosesGame: Bool {
        mode == .free ? isInProgress : (freeGame?.isInProgress ?? false)
    }

    var puzzleNumber: Int? { mode == .daily ? DailyPuzzle.puzzleNumber(day: dailyDay) : nil }

    /// The guesses scored so far, top to bottom.
    var submittedGuesses: [String] { submittedRows.map { $0.compactMap(\.letter).joined() } }

    private var submittedRows: [[Tile]] {
        board.filter { row in
            guard let first = row.first?.evaluation else { return false }
            return first != .empty && first != .tbd
        }
    }

    /// The emoji result grid to share.
    var shareText: String {
        ShareCard.text(title: language.sampleTitle, puzzleNumber: puzzleNumber,
                       rows: submittedRows.map { $0.map(\.evaluation) }, didWin: status == .won)
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
        startClockIfNeeded()
    }

    /// Reveal the correct letter for the next empty slot in the current row.
    /// Returns `false` when there were no hints to spend (the UI then offers the
    /// hint store).
    @discardableResult
    func useHint() -> Bool {
        guard status == .playing, !isRevealing else { return true }
        guard mode == .free else {
            flashToast("Hints are off in the daily game")
            return true
        }
        guard hintsRemaining > 0 else { return false }
        guard currentColumn < GameConstants.wordLength else { return true }
        let targetTokens = language.tokenize(targetWord)
        guard currentColumn < targetTokens.count else { return true }

        setHints(hintsRemaining - 1)
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

        if isHardMode,
           let violation = HardMode.violation(board: board, row: currentRow, guess: guessTokens) {
            switch violation {
            case .missingCorrect(let position, let token):
                flashToast("Position \(position + 1) must be \(token)")
            case .missingPresent(let token):
                flashToast("Guess must contain \(token)")
            }
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
        if mode == .daily {
            DailyPuzzle.save(guesses: submittedGuesses, language: language, day: dailyDay)
        }

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
        stopClock()
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

    /// "Play again": a new free game. In daily mode the finished board stays.
    func newGame() {
        guard mode == .free else {
            showGameOver = false
            return
        }
        startFreeGame()
    }

    private func startFreeGame() {
        gameID = UUID()
        pendingReveal = nil
        stopClock()
        secondsLeft = GameConstants.timeLimitSeconds
        timedOut = false
        isHardMode = UserDefaults.standard.bool(forKey: Self.hardModeKey)
        isTimed = UserDefaults.standard.bool(forKey: Self.timedModeKey)
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
    /// A free game in progress is abandoned, and counts as a loss (so switching
    /// can't be used to protect a streak). Daily progress is saved per language.
    func changeLanguage(_ newLanguage: GameLanguage) {
        guard newLanguage != language else { return }
        // A guess still flipping counts: resolve it first (it may have won).
        if let pending = pendingReveal {
            finishReveal(row: pending.row, guess: pending.guess, evaluations: pending.evaluations)
        }
        if languageSwitchLosesGame {
            StatsStore.record(win: false)
        }
        freeGame = nil
        language = newLanguage
        if mode == .daily { loadDaily() } else { startFreeGame() }
    }

    /// Switch between the daily word and free play; the free game waits while the daily is shown.
    func changeMode(_ newMode: GameMode) {
        guard newMode != mode, !isRevealing else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: GameMode.storageKey)
        if newMode == .daily {
            stopClock()
            freeGame = snapshot()
            loadDaily()
        } else if let saved = freeGame, saved.status == .playing {
            freeGame = nil
            restore(saved)
        } else {
            freeGame = nil
            startFreeGame()
        }
    }

    /// Loads the new day's word when the date has changed (app back in the foreground).
    func refreshDailyIfNeeded() {
        guard mode == .daily, !isRevealing, DailyPuzzle.dayNumber() != dailyDay else { return }
        loadDaily()
    }

    /// Shows today's daily game in the current language, replaying saved guesses
    /// without animation, stats or sounds.
    private func loadDaily() {
        gameID = UUID()
        pendingReveal = nil
        // Hard mode covers the daily game; Timed mode is free play only.
        stopClock()
        isHardMode = UserDefaults.standard.bool(forKey: Self.hardModeKey)
        isTimed = false
        timedOut = false
        dailyDay = DailyPuzzle.dayNumber()
        board = Self.makeEmptyBoard()
        currentRow = 0
        currentColumn = 0
        status = .playing
        keyboardHints = [:]
        isRevealing = false
        toast = nil
        showGameOver = false
        targetWord = DailyPuzzle.word(for: language, day: dailyDay)

        let targetTokens = language.tokenize(targetWord)
        for guess in DailyPuzzle.savedGuesses(language: language, day: dailyDay) where status == .playing {
            let tokens = language.tokenize(guess)
            // Stop at a word that is no longer playable (the word list changed).
            guard tokens.count == GameConstants.wordLength, language.isValidGuess(guess) else { break }
            let evaluations = Self.evaluate(guessTokens: tokens, targetTokens: targetTokens)
            for (index, token) in tokens.enumerated() {
                board[currentRow][index].letter = token
                board[currentRow][index].evaluation = evaluations[index]
            }
            for (index, token) in tokens.enumerated() where evaluations[index].rank > (keyboardHints[token]?.rank ?? 0) {
                keyboardHints[token] = evaluations[index]
            }
            if guess.uppercased() == targetWord {
                status = .won
            } else if currentRow == GameConstants.maxGuesses - 1 {
                status = .lost
            } else {
                currentRow += 1
            }
        }
    }

    // MARK: - Free game snapshot

    private struct Snapshot {
        let board: [[Tile]]
        let currentRow: Int
        let currentColumn: Int
        let status: GameStatus
        let keyboardHints: [String: LetterEvaluation]
        let targetWord: String
        let isHardMode: Bool
        let isTimed: Bool
        let secondsLeft: Int

        var isInProgress: Bool {
            status == .playing && (currentRow > 0 || currentColumn > 0)
        }
    }

    private func snapshot() -> Snapshot {
        Snapshot(board: board, currentRow: currentRow, currentColumn: currentColumn,
                 status: status, keyboardHints: keyboardHints, targetWord: targetWord,
                 isHardMode: isHardMode, isTimed: isTimed, secondsLeft: secondsLeft)
    }

    private func restore(_ saved: Snapshot) {
        gameID = UUID()
        pendingReveal = nil
        board = saved.board
        currentRow = saved.currentRow
        currentColumn = saved.currentColumn
        status = saved.status
        keyboardHints = saved.keyboardHints
        targetWord = saved.targetWord
        // A timed game resumes its paused clock on the next letter.
        isHardMode = saved.isHardMode
        isTimed = saved.isTimed
        secondsLeft = saved.secondsLeft
        timedOut = false
        isRevealing = false
        toast = nil
        showGameOver = false
    }

    // MARK: - Modes

    /// Call after the Hard / Timed settings change: they apply now if the game
    /// hasn't started yet, otherwise from the next game.
    func applyModeSettings() {
        guard status == .playing, !isInProgress else { return }
        isHardMode = UserDefaults.standard.bool(forKey: Self.hardModeKey)
        isTimed = mode == .free && UserDefaults.standard.bool(forKey: Self.timedModeKey)
        secondsLeft = GameConstants.timeLimitSeconds
    }

    private func startClockIfNeeded() {
        guard isTimed, clockTask == nil, status == .playing else { return }
        // Starts (or resumes) with the time left.
        let deadline = Date.now.addingTimeInterval(TimeInterval(secondsLeft))
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                guard let self else { return }
                self.secondsLeft = max(0, Int(left.rounded(.up)))
                if left <= 0 { break }
                try? await Task.sleep(nanoseconds: UInt64(min(left, 0.25) * 1_000_000_000))
            }
            guard let self, !Task.isCancelled else { return }
            self.clockTask = nil
            self.timeUp()
        }
    }

    private func stopClock() {
        clockTask?.cancel()
        clockTask = nil
    }

    /// The clock ran out. A guess still flipping decides it if it ended the game;
    /// otherwise the game is lost.
    private func timeUp() {
        guard status == .playing else { return }
        if let pending = pendingReveal {
            finishReveal(row: pending.row, guess: pending.guess, evaluations: pending.evaluations)
        }
        guard status == .playing else { return }
        isRevealing = false
        status = .lost
        timedOut = true
        StatsStore.record(win: false)
        Haptics.shared.notify(.error)
        SoundManager.shared.play(.lose)
        endGame()
    }

    // MARK: - Armenian word of the day

    /// Today's Armenian word for learners and its English meaning
    /// (see `DailyPuzzle.learnerWord`).
    var armenianWordOfTheDay: (word: String, gloss: String)? {
        let word = DailyPuzzle.learnerWord(day: DailyPuzzle.dayNumber())
        return WordMeanings.armenian[word].map { (word: word, gloss: $0) }
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

    func setModesForTesting(hard: Bool, timed: Bool) {
        isHardMode = hard
        isTimed = timed
    }

    func timeUpForTesting() { timeUp() }

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
