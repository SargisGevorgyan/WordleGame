# WordleGame

A modern, offline‑first Wordle‑style word game built with **pure SwiftUI + MVVM**,
plus a full monetization layer (**StoreKit 2** "Remove Ads" IAP and **Google
Mobile Ads / AdMob** banner + interstitial).

The project builds and runs **with zero external dependencies** — every ad
reference is guarded by `#if canImport(GoogleMobileAds)`, so you get a working
game immediately and switch real ads on when you're ready.

---

## Run it

```bash
cd ios/WordleGame
xcodegen generate          # produces WordleGame.xcodeproj (XcodeGen 2.4+)
open WordleGame.xcodeproj
```

Select the **WordleGame** scheme and an iOS 17+ Simulator, then ⌘R.

> No XcodeGen? `brew install xcodegen`. Or just create a new **iOS App**
> (SwiftUI, iOS 17) in Xcode and drag the `WordleGame/` folder in — the sources
> have no project‑specific configuration beyond `Info.plist`.

Command line:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project WordleGame.xcodeproj -scheme WordleGame \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

17 unit tests cover the scoring algorithm (English + Armenian), win/lose flow,
invalid‑word handling, keyboard‑hint priority, language switching, the hint
system, stats math and Armenian keyboard / word‑list coverage.

---

## Shared word bank (iOS + Android)

Both apps read the same word lists — the single source of truth is
[`shared/words/`](shared/words):

| File | Language |
|------|----------|
| `shared/words/words_en.txt` | English |
| `shared/words/words_hy.txt` | Armenian (Հայերեն) |

One UPPERCASE word per line; blank lines and `#` comments are ignored. Entries
that aren't exactly 5 board letters (Armenian ու counts as one) are skipped at
load time, so a typo can't become an unwinnable target. To add or remove words,
edit these files only: iOS bundles them as resources (`project.yml` /
`WordleGame.xcodeproj`), Android packages them as assets
(`android/app/build.gradle.kts`).

The meaning shown after each game comes from `meanings_en.txt` and
`meanings_hy.txt` in the same folder, one `WORD|meaning` entry per line
(Armenian words carry an English gloss). When you add a word, add its meaning
too: a unit test on each platform fails if a playable word has none.

---

## Android

Native Kotlin + Jetpack Compose app in [`android/`](android), with the same
rules as iOS: 6 tries, two‑pass duplicate‑aware scoring, English / Հայերեն with
the KDWIN Armenian keyboard and the ու digraph as one tile, hints (start at 3,
+1 per win up to 5), stats, language auto‑detection, physical‑keyboard input
and the dark‑indigo look. Ads, in‑app purchases and Game Center are iOS‑only
for now.

```bash
cd android
./gradlew testDebugUnitTest   # game rules + shared word bank checks
./gradlew assembleDebug       # app/build/outputs/apk/debug/app-debug.apk
```

Or open `android/` in Android Studio and run the **app** configuration.
Requires JDK 17 and the Android SDK (compileSdk 35, minSdk 26). CI builds the
APK on every PR touching `android/` or `shared/` (`.github/workflows/android.yml`)
and attaches it as an artifact.

```
android/app/src/main/java/com/sargisgevorgyan/wordlegame/
├─ game/            pure Kotlin, unit-tested: GameLanguage, WordBank, GameRules, Stats
├─ GameViewModel.kt state, reveal timing, hints, persistence (SharedPreferences)
├─ MainActivity.kt
└─ ui/              Compose: WordleApp (HUD, aurora background, hardware keys),
                    Board (flip / pop / shake), Keyboard, Dialogs (game over, settings)
```

---

## Architecture (MVVM)

```
WordleGame/
├─ App/
│  └─ WordleGameApp.swift        @main; injects GameViewModel / StoreManager / AdManager
├─ Models/                        pure value types, no SwiftUI state
│  ├─ GameModels.swift            LetterEvaluation, Tile, GameStatus, GameConstants
│  ├─ GameLanguage.swift          English / Հայերեն — word list, keyboard layout, casing
│  ├─ WordBank.swift              loads the shared word bank (shared/words/*.txt) from the bundle
│  └─ StatsStore.swift            UserDefaults persistence (same keys as @AppStorage)
├─ ViewModels/
│  └─ GameViewModel.swift         @MainActor ObservableObject — the single source of truth
├─ Views/
│  ├─ RootView.swift              screen layout, glass HUD, neon title, hardware‑kbd bridge
│  ├─ AnimatedBackground.swift    dark‑indigo gradient + drifting aurora glows & particles
│  ├─ BoardView.swift / TileView.swift   3D frosted tiles, spring flip + pop‑in
│  ├─ KeyboardView.swift          frosted‑glass keys, neon hint colours, gradient ⌫ / ↵
│  ├─ StatsView.swift             animated circular stat rings (@AppStorage)
│  ├─ GameOverView.swift          frosted modal, bouncy spring, stat rings, gradient CTA
│  └─ SettingsView.swift          language picker / Remove Ads / Restore / sound toggle
├─ Monetization/
│  ├─ StoreManager.swift          StoreKit 2 (Product.products, purchase, entitlements)
│  ├─ AdManager.swift             GADInterstitialAd lifecycle + 3‑round cadence
│  └─ BannerAdView.swift          UIViewControllerRepresentable around GADBannerView
├─ Services/
│  ├─ Haptics.swift               UIImpactFeedbackGenerator / UINotificationFeedbackGenerator
│  └─ SoundManager.swift          lightweight system‑sound SFX (no bundled audio)
├─ Support/
│  ├─ Color+Wordle.swift          premium dark‑indigo palette + reusable gradients
│  ├─ GlassStyles.swift           `.glass()` (Glassmorphism 2.0) + `.neonGlow()` modifiers
│  └─ ShakeEffect.swift           GeometryEffect shake on invalid submission
└─ Resources/
   └─ Products.storekit           local StoreKit config for Simulator testing
```

### Visual style

Premium dark theme, locked to `.dark`. Deep indigo `AnimatedBackground` with four
slow blurred aurora blobs (`.blendMode(.screen)`) and ~16 drifting particles,
driven by one `TimelineView(.animation)` clock. Glassmorphism 2.0 (`.glass()` =
`.ultraThinMaterial` + vibrant gradient hairline stroke + depth shadow) on the
HUD, keyboard panel, toasts and the end‑game modal. Neon‑glow title **ԲԱՌ‑ԽԱՂ**.
Tiles are frosted with a top‑lit gradient and flip with
`.spring(response: 0.45, dampingFraction: 0.6)`; revealed tiles fill with a
vibrant gradient (neon green / warm yellow / glassy slate) and cast a coloured
glow. Keyboard keys are frosted glass; hinted keys take the status gradient +
glow; **⌫** and **↵** are larger with action gradients.

### In‑game HUD

Single glass capsule at the top: a **💡 hint** pill (count from
`@AppStorage("hintsRemaining")`, starts at 3, +1 per win, capped at 5 — tapping
auto‑types the correct letter for the next slot), a **Remove Ads** button
(1‑tap StoreKit purchase; shows a spinner while purchasing and a gradient
**PRO ✓** badge once owned), and the settings gear.

### Game rules

* 6 attempts, 5‑letter target chosen at random from the active language's word
  list on launch / "Play Again".
* Two‑pass scoring with correct duplicate‑letter handling
  (`GameViewModel.evaluate`): greens first, then yellows drawn from the remaining
  letter pool, everything else grey.
* Grid tiles: staggered 3D flip on reveal; pop when a letter is entered.
* On‑screen keyboard keys recolour using the strongest hint seen
  (green > yellow > grey, never downgraded).
* Invalid / short word → row shake + toast + warning haptic.
* Physical keyboard: `RootView` is `.focusable()` and forwards `.onKeyPress`
  to `GameViewModel.handleKeyPress` (letters, Return = submit, Backspace = delete).
* Stats via `@AppStorage`: `gamesPlayed`, `gamesWon`, `currentStreak`, `maxStreak`
  → shown as Played / Win % / Streak / Max.

### Game modes (Settings → Game Modes, both apps)

* **Hard mode**: revealed hints must be used in later guesses. A green letter
  stays in its spot, and a yellow letter must appear somewhere
  (`HardMode.violation`).
* **Timed mode**: 3 minutes per free-play game; the clock starts with the
  first letter, pauses while the daily game is on screen, and running out is a
  loss ("TIME'S UP").
* Hard mode also applies to the daily game.
* Changing a mode mid-game applies from the next game; before the first
  letter it applies straight away.

### Armenian word of the day

Every game-over card also shows an **Armenian word of the day** for learners,
with its English meaning from `shared/words/meanings_hy.txt`. It follows the
daily puzzle's fixed word order, half the list away from today's daily answer
so it never spoils it (`DailyPuzzle.learnerWord`), and is the same on iOS and
Android.

### Language (English / Հայերեն)

* `GameLanguage` (persisted in `@AppStorage("gameLanguage")`) owns everything
  language‑specific: the word list, the on‑screen keyboard layout, and the
  canonical letter casing. Switch it in **Settings ▸ Language** — the segmented
  control starts a fresh game in the chosen language.
* All guesses / targets / keyboard hints are normalised to **UPPERCASE** for both
  languages, so the scoring path is identical. `GameLanguage.normalize(_:)`
  maps a typed character (soft or hardware keyboard) into the language's alphabet
  and rejects anything outside it (ASCII A–Z for English, the Armenian block
  U+0531–U+058F for Հայերեն). Ligatures whose uppercase expands to two letters
  (e.g. `և` → `ԵՎ`) are treated as no‑ops rather than crashing `Character(_:)`.
* **Armenian keyboard** — the KDWIN‑style phonetic layout in
  `GameLanguage.keyboardRows` (maintained directly in that file). It covers the
  full 38‑letter alphabet, so every word is typable. Rows reach 12 keys, so
  `keyboardIsCompact` shrinks key metrics on phone widths.
* **Armenian words** — `WordBank.armenian` is the raw source list;
  `WordBank.armenianPlayable` (used for play) filters it to entries that are
  exactly 5 characters, so the 6–7‑char digraph spellings (`ԳԱՐՈՒՆ`, `ԷՈՒԹՅՈՒ`, …)
  can't be picked as an unwinnable target. `testArmenianPlayableWordsAreFiveLetterUppercase`
  guards this.

---

## Monetization

### 1. Remove Ads — StoreKit 2 (`StoreManager.swift`)

* Non‑consumable product id: **`com.app.removeads`** (`StoreManager.removeAdsProductID`).
* Loads with `Product.products(for:)`, buys with `product.purchase()`,
  verifies `VerificationResult`, listens to `Transaction.updates`, restores with
  `AppStore.sync()` + `Transaction.currentEntitlements`.
* Entitlement is written to `UserDefaults["isAdFree"]`, the exact key the views
  read via `@AppStorage("isAdFree") var isAdFree = false`.
* UI: **Remove Ads ($1.99)** and **Restore Purchases** buttons in
  `SettingsView` (gear icon, top‑right).

**Testing in the Simulator:** Edit Scheme ▸ Run ▸ Options ▸
**StoreKit Configuration → `Products.storekit`**. The purchase then works
without App Store Connect.

### 2. AdMob (`AdManager.swift`, `BannerAdView.swift`)

* `BannerAdView` = `UIViewControllerRepresentable` hosting a `GADBannerView`
  (adaptive size), pinned to the bottom of `RootView` via `BannerAdContainer`.
* `AdManager` (`@MainActor ObservableObject`) loads a `GADInterstitialAd` and,
  through `registerRoundCompleted(isAdFree:)`, presents one **after every 3rd
  completed game** — skipped entirely when `isAdFree == true`.
* `AdManager.bootstrap()` (called from `WordleGameApp.init`) starts the SDK.
* Ad Unit IDs — `#if DEBUG` uses Google's official test IDs so it works in the
  Simulator right away:
  * Banner `ca-app-pub-3940256099942544/2934735716`
  * Interstitial `ca-app-pub-3940256099942544/4411468910`
  * Release build reads the placeholder constants at the top of `AdManager.swift`
    — replace with your real IDs.
* `Info.plist` already contains a test `GADApplicationIdentifier`,
  `NSUserTrackingUsageDescription` and a starter `SKAdNetworkItems` list.

**AdMob SDK:** linked as a Swift package
(`https://github.com/googleads/swift-package-manager-google-mobile-ads`, pinned
to 11.13.0 up to 12.0) in both `project.yml` and the Xcode project, so every
`#if canImport(GoogleMobileAds)` ad path is active. Xcode resolves the package
on first open.

> **SDK version note.** This code uses the classic `GAD`‑prefixed API
> (`GADMobileAds`, `GADBannerView`, `GADInterstitialAd`, `GADRequest`), available
> through **Google‑Mobile‑Ads‑SDK 11.x** — pin to `11.13.0` for a drop‑in build.
> v12+ renamed those symbols in Swift (`MobileAds`, `BannerView`,
> `InterstitialAd`, `Request`); rename accordingly if you take the latest.

---

## Requirements

* Xcode 15+ (developed/tested on Xcode 16 / iOS 17 SDK)
* iOS 17.0 deployment target (`.onKeyPress`, two‑parameter `.onChange`)
* Swift 5 language mode, `@MainActor` throughout the view‑model / managers
