//
//  WordleGameTests.swift
//  WordleGameTests
//

import XCTest
@testable import WordleGame

final class WordleGameTests: XCTestCase {

    // MARK: - Evaluation

    func testExactMatchIsAllCorrect() {
        let result = GameViewModel.evaluate(guess: "FOCUS", target: "FOCUS")
        XCTAssertEqual(result, Array(repeating: .correct, count: 5))
    }

    func testAbsentLetters() {
        let result = GameViewModel.evaluate(guess: "VWXYZ", target: "PLANT")
        XCTAssertEqual(result, Array(repeating: .absent, count: 5))
    }

    func testDuplicateLettersInGuessArePartiallyMarked() {
        // target "CLASS" has a single 'S' beyond the correctly-placed one.
        let result = GameViewModel.evaluate(guess: "SASSY", target: "CLASS")
        XCTAssertEqual(result, [.present, .present, .absent, .correct, .absent])
    }

    func testPresentButWrongPosition() {
        let result = GameViewModel.evaluate(guess: "ABBEY", target: "BATHE")
        XCTAssertEqual(result, [.present, .present, .absent, .present, .absent])
    }

    func testEvaluationIsCaseInsensitive() {
        XCTAssertEqual(GameViewModel.evaluate(guess: "focus", target: "FOCUS"),
                       Array(repeating: .correct, count: 5))
    }

    func testArmenianEvaluation() {
        // ՍԵՂԱՆ vs ՍԻՐՏՆ  → Ս correct, Ն correct, rest absent.
        let result = GameViewModel.evaluate(guess: "ՍԵՂԱՆ", target: "ՍԻՐՏՆ")
        XCTAssertEqual(result, [.correct, .absent, .absent, .absent, .correct])
    }

    func testArmenianDigraphIsScoredAsOneLetter() {
        // Tokens: ԳԱՐՈՒՆ -> [Գ, Ա, Ր, ՈՒ, Ն]  vs  ԽՈՒՄԲՍ won't tokenise to 5…
        // Use ԳԱՐՈՒՆ vs ԳՈՒՅՆՍ -> [Գ, ՈՒ, Յ, Ն, Ս]
        let g = GameLanguage.armenian.tokenize("ԳԱՐՈՒՆ")   // [Գ, Ա, Ր, ՈՒ, Ն]
        let t = GameLanguage.armenian.tokenize("ԳՈՒՅՆՍ")    // [Գ, ՈՒ, Յ, Ն, Ս]
        XCTAssertEqual(g.count, 5)
        XCTAssertEqual(t.count, 5)
        let result = GameViewModel.evaluate(guessTokens: g, targetTokens: t)
        // Գ correct; Ա absent; Ր absent; ՈՒ present (wrong slot); Ն present.
        XCTAssertEqual(result, [.correct, .absent, .absent, .present, .present])
    }

    // MARK: - Game flow

    @MainActor
    func testWinningFlowUpdatesStatus() {
        let vm = GameViewModel(targetWord: "PLANT")
        type("plant", into: vm)
        vm.submit()
        // reveal is async; force the resolution synchronously for the test.
        vm.forceFinishRevealForTesting(guess: vm.currentGuess)
        XCTAssertEqual(vm.status, .won)
    }

    @MainActor
    func testArmenianWinningFlow() {
        let vm = GameViewModel(targetWord: "ՍԵՂԱՆ", language: .armenian)
        type("ՍԵՂԱՆ", into: vm)
        XCTAssertEqual(vm.currentGuess, "ՍԵՂԱՆ")
        vm.submit()
        vm.forceFinishRevealForTesting(guess: vm.currentGuess)
        XCTAssertEqual(vm.status, .won)
    }

    @MainActor
    func testArmenianDigraphMergeWhileTyping() {
        let vm = GameViewModel(targetWord: "ԳԱՐՈՒՆ", language: .armenian)
        // Type Գ Ա Ր Ո Ւ Ն — the Ո+Ւ must collapse into a single "ՈՒ" tile.
        type("ԳԱՐՈՒՆ", into: vm)
        XCTAssertEqual(vm.currentTokens, ["Գ", "Ա", "Ր", "ՈՒ", "Ն"])
        XCTAssertEqual(vm.currentColumn, 5)
        XCTAssertEqual(vm.currentGuess, "ԳԱՐՈՒՆ")

        vm.submit()
        vm.forceFinishRevealForTesting(guess: vm.currentGuess)
        XCTAssertEqual(vm.status, .won)
    }

    @MainActor
    func testDeleteRemovesWholeDigraphTile() {
        let vm = GameViewModel(targetWord: "ԳԱՐՈՒՆ", language: .armenian)
        type("ԳԱՐՈՒ", into: vm)               // Գ Ա Ր [ՈՒ]
        XCTAssertEqual(vm.currentTokens, ["Գ", "Ա", "Ր", "ՈՒ"])
        vm.deleteLetter()
        XCTAssertEqual(vm.currentTokens, ["Գ", "Ա", "Ր"])
    }

    @MainActor
    func testInvalidWordTriggersShakeAndDoesNotAdvance() {
        let vm = GameViewModel(targetWord: "PLANT")
        type("zzzzz", into: vm)
        let tokenBefore = vm.shakeToken
        vm.submit()
        XCTAssertEqual(vm.currentRow, 0)
        XCTAssertGreaterThan(vm.shakeToken, tokenBefore)
    }

    @MainActor
    func testDeleteRemovesLastLetter() {
        let vm = GameViewModel(targetWord: "PLANT")
        type("pla", into: vm)
        vm.deleteLetter()
        XCTAssertEqual(vm.currentGuess, "PL")
    }

    @MainActor
    func testKeyboardHintsMergeWithPriority() {
        let vm = GameViewModel(targetWord: "SASSY")
        vm.mergeHintsForTesting(guess: "SOBER", evaluations: [.correct, .absent, .absent, .absent, .absent])
        vm.mergeHintsForTesting(guess: "SPACE", evaluations: [.present, .absent, .absent, .absent, .absent])
        // 'S' was already .correct — must not be downgraded to .present.
        XCTAssertEqual(vm.keyboardHints["S"], .correct)
    }

    func testLanguageDefaultFallsBackToLocaleThenIsOverridable() {
        let key = GameLanguage.storageKey
        let saved = UserDefaults.standard.string(forKey: key)
        defer { saved.map { UserDefaults.standard.set($0, forKey: key) } }

        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(GameLanguage.hasExplicitChoice)
        XCTAssertEqual(GameLanguage.current, GameLanguage.systemDefault)
        XCTAssertTrue(GameLanguage.allCases.contains(GameLanguage.systemDefault))

        UserDefaults.standard.set(GameLanguage.armenian.rawValue, forKey: key)
        XCTAssertTrue(GameLanguage.hasExplicitChoice)
        XCTAssertEqual(GameLanguage.current, .armenian)   // explicit choice wins over locale
    }

    @MainActor
    func testChangeLanguageStartsNewGameInThatLanguage() {
        let vm = GameViewModel(language: .english)
        vm.changeLanguage(.armenian)
        XCTAssertEqual(vm.language, .armenian)
        XCTAssertTrue(WordBank.armenian.contains(vm.targetWord))
        XCTAssertEqual(vm.currentRow, 0)
    }

    @MainActor
    func testSwitchingLanguageMidGameCountsAsLossAndDropsPendingReveal() {
        StatsStore.reset()
        let vm = GameViewModel(targetWord: "PLANT")
        type("crane", into: vm)
        vm.submit()                          // reveal still pending
        vm.changeLanguage(.armenian)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: StatsKey.gamesPlayed), 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: StatsKey.gamesWon), 0)
        XCTAssertEqual(vm.language, .armenian)
        XCTAssertEqual(vm.currentRow, 0)
        XCTAssertEqual(vm.status, .playing)
        XCTAssertFalse(vm.isRevealing)
        StatsStore.reset()
    }

    @MainActor
    func testUseHintReturnsFalseWhenEmptyAndAddHintsStacks() {
        UserDefaults.standard.set(0, forKey: GameViewModel.hintsKey)
        let vm = GameViewModel(targetWord: "PLANT")
        XCTAssertFalse(vm.useHint(), "useHint should report empty so the UI can offer the store")
        XCTAssertEqual(vm.currentGuess, "")

        vm.addHints(20)                     // e.g. a purchased pack
        XCTAssertEqual(vm.hintsRemaining, 20, "purchased hints stack past the free ceiling")
        XCTAssertTrue(vm.useHint())
        XCTAssertEqual(vm.currentGuess, "P")
        XCTAssertEqual(vm.hintsRemaining, 19)
    }

    @MainActor
    func testHintTypesTheCorrectNextLetterAndDecrementsCount() {
        UserDefaults.standard.set(2, forKey: GameViewModel.hintsKey)
        let vm = GameViewModel(targetWord: "PLANT")
        vm.useHint()
        XCTAssertEqual(vm.currentGuess, "P")
        XCTAssertEqual(vm.hintsRemaining, 1)
        vm.useHint()
        XCTAssertEqual(vm.currentGuess, "PL")
        XCTAssertEqual(vm.hintsRemaining, 0)
        vm.useHint() // no-op at zero
        XCTAssertEqual(vm.currentGuess, "PL")
    }

    // MARK: - Stats

    func testWinPercentage() {
        XCTAssertEqual(StatsStore.winPercentage(played: 0, won: 0), 0)
        XCTAssertEqual(StatsStore.winPercentage(played: 4, won: 1), 25)
        XCTAssertEqual(StatsStore.winPercentage(played: 3, won: 2), 67)
    }

    // MARK: - Word banks

    func testSharedWordFilesAreBundledAndParsed() {
        // Loaded from shared/words/*.txt (the bank shared with Android).
        XCTAssertFalse(WordBank.english.isEmpty)
        XCTAssertFalse(WordBank.armenian.isEmpty)
        XCTAssertEqual(WordBank.parse("# comment\n\n plant \r\nՔԱՂԱՔ\n"), ["PLANT", "ՔԱՂԱՔ"])
    }

    func testEnglishPlayableWordsAreFiveLetterUppercase() {
        let playable = GameLanguage.englishPlayableWords
        XCTAssertGreaterThanOrEqual(playable.count, 100)
        for word in playable {
            XCTAssertEqual(word.count, 5, "\(word) is not 5 letters")
            XCTAssertEqual(word, word.uppercased())
        }
        // Wrong-length entries in the raw list are filtered out of play.
        XCTAssertFalse(GameLanguage.english.isValidGuess("SILK"))
        XCTAssertTrue(GameLanguage.english.isValidGuess("PLANT"))
    }

    func testArmenianPlayableWordsAreFiveTokens() {
        let playable = GameLanguage.armenianPlayableWords
        XCTAssertGreaterThanOrEqual(playable.count, 50)
        for word in playable {
            XCTAssertEqual(GameLanguage.armenian.tokenize(word).count, 5,
                           "\(word) is not 5 Armenian letters (ու counts as one)")
            XCTAssertEqual(word, word.uppercased())
        }
        // ԳԱՐՈՒՆ = Գ Ա Ր ՈՒ Ն → 5 letters → playable.
        XCTAssertTrue(playable.contains("ԳԱՐՈՒՆ"))
        XCTAssertTrue(GameLanguage.armenian.isValidGuess("ԳԱՐՈՒՆ"))
        // ԱՇՈՒՆ = Ա Շ ՈՒ Ն → only 4 letters → not playable.
        XCTAssertFalse(playable.contains("ԱՇՈՒՆ"))
        XCTAssertFalse(GameLanguage.armenian.isValidGuess("ԱՇՈՒՆ"))
    }

    func testArmenianKeyboardCoversEveryPlayableWord() {
        let keys = Set(GameLanguage.armenian.keyboardRows
            .flatMap { $0 }
            .filter { $0 != "ENTER" && $0 != "DELETE" }
            .flatMap { Array($0) })
        for word in GameLanguage.armenianPlayableWords {
            for letter in word {   // raw characters, incl. the Ւ inside a ՈՒ digraph
                XCTAssertTrue(keys.contains(letter),
                              "‘\(letter)’ in \(word) is missing from the Armenian keyboard")
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func type(_ text: String, into vm: GameViewModel) {
        for character in text { vm.insert(character) }
    }

    // MARK: - Cloud stats merge

    func testMergeKeepsLargerCountsAndNewerCurrentStreak() {
        let phone = StatsSnapshot(gamesPlayed: 10, gamesWon: 8, currentStreak: 0, maxStreak: 6, updatedAt: 200)
        let tablet = StatsSnapshot(gamesPlayed: 12, gamesWon: 7, currentStreak: 4, maxStreak: 5, updatedAt: 100)
        let merged = phone.merged(with: tablet)
        XCTAssertEqual(merged.gamesPlayed, 12)
        XCTAssertEqual(merged.gamesWon, 8)
        XCTAssertEqual(merged.currentStreak, 0)    // phone changed last: its loss broke the streak
        XCTAssertEqual(merged.maxStreak, 6)
        XCTAssertEqual(merged.updatedAt, 200)
        XCTAssertEqual(merged, tablet.merged(with: phone))
    }

    func testMergeDropsStatsOlderThanAReset() {
        let reset = StatsSnapshot(updatedAt: 300, resetAt: 300)
        let old = StatsSnapshot(gamesPlayed: 50, gamesWon: 40, currentStreak: 9, maxStreak: 12, updatedAt: 250)
        XCTAssertEqual(old.merged(with: reset), reset)
        XCTAssertEqual(reset.merged(with: old), reset)
    }

    func testMergeKeepsGamesPlayedAfterAReset() {
        let reset = StatsSnapshot(updatedAt: 300, resetAt: 300)
        let after = StatsSnapshot(gamesPlayed: 1, gamesWon: 1, currentStreak: 1, maxStreak: 1, updatedAt: 400, resetAt: 300)
        XCTAssertEqual(reset.merged(with: after), after)
    }

    func testAchievementThresholds() {
        typealias A = GameCenterManager.Achievement
        XCTAssertEqual(A.allCases.filter { $0.isEarned(wins: 0, bestStreak: 0) }, [])
        XCTAssertEqual(A.allCases.filter { $0.isEarned(wins: 12, bestStreak: 3) }, [.firstWin, .wins10, .streak3])
    }
}
