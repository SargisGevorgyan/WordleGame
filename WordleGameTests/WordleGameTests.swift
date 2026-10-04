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
        let vm = GameViewModel(language: .english, mode: .free)
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

    // MARK: - Hard mode

    func testHardModeRequiresGreensInPlace() {
        // PLANT vs CRANE: A and N green.
        let row = zip(["P", "L", "A", "N", "T"], GameViewModel.evaluate(guess: "PLANT", target: "CRANE"))
            .map { Tile(letter: $0, evaluation: $1) }
        var board = Array(repeating: row, count: 1)
        board.append(row)
        XCTAssertEqual(HardMode.violation(board: board, row: 1, guess: ["S", "L", "A", "T", "E"]),
                       .missingCorrect(position: 3, token: "N"))
        XCTAssertNil(HardMode.violation(board: board, row: 1, guess: ["C", "R", "A", "N", "E"]))
    }

    func testHardModeRequiresYellowsSomewhere() {
        // EERIE: two yellow Es → later guesses need at least two Es.
        let row = ["E", "E", "R", "I", "E"].enumerated()
            .map { Tile(letter: $1, evaluation: $0 < 2 ? .present : .absent) }
        XCTAssertEqual(HardMode.violation(board: [row], row: 1, guess: ["C", "R", "A", "N", "E"]),
                       .missingPresent(token: "E"))
        XCTAssertNil(HardMode.violation(board: [row], row: 1, guess: ["E", "X", "E", "R", "T"]))
    }

    @MainActor
    func testHardModeRejectsGuessThatIgnoresHints() {
        let vm = GameViewModel(targetWord: "CRANE")
        vm.setModesForTesting(hard: true, timed: false)
        type("plant", into: vm)
        vm.submit()
        vm.forceFinishRevealForTesting(guess: vm.currentGuess)
        XCTAssertEqual(vm.currentRow, 1)

        type("slate", into: vm)
        let tokenBefore = vm.shakeToken
        vm.submit()
        XCTAssertGreaterThan(vm.shakeToken, tokenBefore)
        XCTAssertFalse(vm.isRevealing)
        XCTAssertEqual(vm.currentRow, 1)
    }

    // MARK: - Timed mode

    @MainActor
    func testTimeUpLosesTheGame() {
        let vm = GameViewModel(targetWord: "CRANE")
        vm.setModesForTesting(hard: false, timed: true)
        type("pl", into: vm)
        vm.timeUpForTesting()
        XCTAssertEqual(vm.status, .lost)
        XCTAssertTrue(vm.timedOut)

        vm.newGame()
        XCTAssertFalse(vm.timedOut)
        XCTAssertEqual(vm.secondsLeft, GameConstants.timeLimitSeconds)
    }

    // MARK: - Meanings

    func testGlossaryParsesTabSeparatedLines() {
        let glossary = Glossary.parse("# c\n\nԳԱՐՈՒՆ\tspring (season)\nBAD LINE\nՔԱՂԱՔ\t \n")
        XCTAssertEqual(glossary.entries.map(\.word), ["ԳԱՐՈՒՆ"])
        XCTAssertEqual(glossary.meaning("գարուն"), "spring (season)")
        XCTAssertNil(glossary.meaning("ՔԱՂԱՔ"))
    }

    func testSharedArmenianGlossesMatchTheWordBank() {
        let entries = Glossary.armenian.entries
        XCTAssertGreaterThanOrEqual(entries.count, 400)
        let words = Set(WordBank.armenian)
        for entry in entries {
            XCTAssertTrue(words.contains(entry.word), "\(entry.word) is glossed but not in the word bank")
        }
    }

    func testWordOfTheDayMatchesAndroidDayNumbering() {
        // 2026-10-04 is day 20730 since 1970-01-01, whatever the time of day or zone.
        var calendar = Calendar(identifier: .gregorian)
        let zone = TimeZone(identifier: "Asia/Yerevan")!
        calendar.timeZone = zone
        let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 23, minute: 30))!
        XCTAssertEqual(Glossary.epochDay(for: lateEvening, timeZone: zone), 20730)
        XCTAssertEqual(Glossary.dayIndex(0, count: 7), 0)
        XCTAssertEqual(Glossary.dayIndex(-1, count: 7), ((-7919 % 7) + 7) % 7)

        let daily = Glossary.armenian.wordOfTheDay(on: lateEvening, playable: GameLanguage.armenianPlayableSet)
        XCTAssertNotNil(daily)
        XCTAssertTrue(GameLanguage.armenianPlayableSet.contains(daily?.word ?? ""))

    // MARK: - Daily word

    // The Android tests assert these same vectors, so both apps pick the same word.
    func testSplitMixMatchesReferenceVectors() {
        var random = DailyPuzzle.SplitMix64(state: DailyPuzzle.seed)
        XCTAssertEqual(random.next(), 0x92f8d4616f6e05f0)
        XCTAssertEqual(random.next(), 0x3fe1473bb8454ca4)
    }

    func testDailyOrderMatchesReferenceShuffle() {
        XCTAssertEqual(DailyPuzzle.order(count: 10), [3, 7, 1, 6, 8, 0, 9, 2, 5, 4])
        XCTAssertEqual(DailyPuzzle.order(count: 457).sorted(), Array(0..<457))
    }

    func testDayNumberCountsLocalDaysFromEpoch() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Yerevan")!
        func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Int {
            let date = calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
            return DailyPuzzle.dayNumber(for: date, calendar: calendar)
        }
        XCTAssertEqual(day(2026, 10, 4), 0)
        XCTAssertEqual(day(2026, 10, 4, hour: 23), 0)
        XCTAssertEqual(day(2026, 10, 5, hour: 0), 1)
        XCTAssertEqual(day(2026, 11, 4), 31)
        XCTAssertEqual(day(2026, 10, 3), -1)
        XCTAssertEqual(DailyPuzzle.puzzleNumber(day: 0), 1)
    }

    func testDailyWordIsStableAndPlayable() {
        for language in GameLanguage.allCases {
            let count = language.words.count
            XCTAssertEqual(DailyPuzzle.word(for: language, day: 3), DailyPuzzle.word(for: language, day: 3 + count))
            XCTAssertEqual(DailyPuzzle.word(for: language, day: -1), DailyPuzzle.word(for: language, day: count - 1))
            XCTAssertTrue(language.isValidGuess(DailyPuzzle.word(for: language, day: 0)))
        }
    }

    @MainActor
    func testShareTextShowsTheColouredGrid() {
        let vm = GameViewModel(targetWord: "PLANT")
        for guess in ["CRANE", "SLATE", "PLANT"] {
            type(guess.lowercased(), into: vm)
            vm.forceFinishRevealForTesting(guess: guess)
        }
        XCTAssertEqual(vm.status, .won)
        XCTAssertEqual(vm.shareText, "WORDY 3/6\n\n⬛⬛🟩🟩⬛\n⬛🟩🟩🟨⬛\n🟩🟩🟩🟩🟩")
        StatsStore.reset()
    }

    @MainActor
    func testDailyProgressIsRestoredWithoutRecordingStats() {
        StatsStore.reset()
        let day = DailyPuzzle.dayNumber()
        let word = DailyPuzzle.word(for: .english, day: day)
        let miss = GameLanguage.english.words.first { $0 != word }!
        DailyPuzzle.save(guesses: [miss, word], language: .english, day: day)
        defer { UserDefaults.standard.removeObject(forKey: "daily.en") }

        let vm = GameViewModel(language: .english, mode: .daily)
        XCTAssertEqual(vm.targetWord, word)
        XCTAssertEqual(vm.status, .won)
        XCTAssertEqual(vm.submittedGuesses, [miss, word])
        XCTAssertTrue(vm.shareText.hasPrefix("WORDY #\(day + 1) 2/6"))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: StatsKey.gamesPlayed), 0)

        DailyPuzzle.save(guesses: [miss], language: .english, day: day - 1)
        XCTAssertEqual(GameViewModel(language: .english, mode: .daily).currentRow, 0,
                       "yesterday's progress is ignored")
    }

    @MainActor
    func testDailyHintsAreOffAndFreeGameWaitsWhileDailyIsShown() {
        UserDefaults.standard.set(3, forKey: GameViewModel.hintsKey)
        let vm = GameViewModel(targetWord: "PLANT")
        type("cr", into: vm)
        vm.changeMode(.daily)
        XCTAssertTrue(vm.useHint())
        XCTAssertEqual(vm.hintsRemaining, 3)
        XCTAssertTrue(vm.languageSwitchLosesGame)
        vm.changeMode(.free)
        XCTAssertEqual(vm.targetWord, "PLANT")
        XCTAssertEqual(vm.currentGuess, "CR")
        UserDefaults.standard.removeObject(forKey: GameMode.storageKey)
    }

    // MARK: - Helpers

    @MainActor
    private func type(_ text: String, into vm: GameViewModel) {
        for character in text { vm.insert(character) }
    }
}
