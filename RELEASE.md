# Releasing **Wordy** to the App Store

Everything below is what you must do to ship this project. Items are ordered
roughly in the sequence you'll do them. Anything marked 🔧 is a placeholder in the
code that **must** be replaced before a production build.

---

## 0. Accounts & tools

- [ ] Apple Developer Program membership ($99/yr) — <https://developer.apple.com/account>
- [ ] Xcode 16+ (project is built with the iOS 17 SDK, deployment target **iOS 17.0**)
- [ ] [XcodeGen](https://github.com/yonwoo9/XcodeGen) (`brew install xcodegen`) — the
      `.xcodeproj` is generated from `project.yml`
- [ ] Google AdMob account — <https://apps.admob.com> (only if you ship ads)

Regenerate the project after any `project.yml` change:

```bash
cd ios/WordleGame
xcodegen generate
open WordleGame.xcodeproj
```

---

## 1. Identifiers & signing

### 1.1 Bundle identifier
Set to **`com.sargisgevorgyan.wordlegame`** (`project.yml` →
`PRODUCT_BUNDLE_IDENTIFIER`; tests use `…​.wordlegame.tests`). Product and
leaderboard IDs are namespaced under it (see §2b / §3).

- [ ] Register the App ID `com.sargisgevorgyan.wordlegame` in the Apple Developer
      portal (Certificates, Identifiers & Profiles) **with _In-App Purchase_ and
      _Game Center_ capabilities enabled**.

### 1.2 Signing team
- [ ] 🔧 In `project.yml` set `settings.base.DEVELOPMENT_TEAM` to your 10-char Team ID
      (currently empty). Or set it in Xcode → target → Signing & Capabilities →
      *Automatically manage signing* + your team.
- [ ] Confirm `CODE_SIGN_STYLE = Automatic` works, or create an App Store
      distribution provisioning profile for manual signing.

### 1.3 Version / build number
`project.yml` → `settings.base`:

```yaml
MARKETING_VERSION: "1.0"      # user-facing, e.g. 1.0.0
CURRENT_PROJECT_VERSION: "1"  # build number — bump every upload
```

- [ ] Set `MARKETING_VERSION` for the release.
- [ ] Bump `CURRENT_PROJECT_VERSION` on **every** TestFlight / App Store upload.

---

## 2. Google Mobile Ads (AdMob)

> The whole ad layer is wrapped in `#if canImport(GoogleMobileAds)`. With no SDK
> linked the app builds and runs fine but shows **no ads** and the rewarded-ad
> button just grants a hint directly. To ship real ads you must add the SDK.

### 2.1 Add the SDK
- [ ] Xcode → *File ▸ Add Package Dependencies…* →
      `https://github.com/googleads/googleads-mobile-ios-sdk`
      _or_ uncomment the `packages:` + `dependencies:` blocks in `project.yml`
      and re-run `xcodegen generate`.
- [ ] ⚠️ **SDK version:** the code uses the classic `GAD`-prefixed API
      (`GADBannerView`, `GADInterstitialAd`, `GADRewardedAd`, `GADRequest`,
      `GADMobileAds`). That API exists **up to Google-Mobile-Ads-SDK 11.x** —
      pin the package to `11.13.0`. SDK **12+ renamed** these symbols in Swift
      (`BannerView`, `InterstitialAd`, `RewardedAd`, `Request`, `MobileAds`);
      if you take 12+, rename them in `AdManager.swift` / `BannerAdView.swift`.

### 2.2 AdMob console
- [ ] Create the app in AdMob, link it to its App Store listing once live.
- [ ] Create ad units: **Banner**, **Interstitial**, **Rewarded**.
- [ ] Publish `app-ads.txt` at your developer-site root (AdMob → *app-ads.txt*).

### 2.3 🔧 Replace the IDs in code

**`WordleGame/Info.plist`**
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>   <!-- 🔧 Google sample — replace -->
```

**`WordleGame/Monetization/AdManager.swift`** — the `#else` (Release) branch:
```swift
static let bannerAdUnitID       = "ca-app-pub-0000000000000000/0000000000"  // 🔧
static let interstitialAdUnitID = "ca-app-pub-0000000000000000/1111111111"  // 🔧
static let rewardedAdUnitID     = "ca-app-pub-0000000000000000/2222222222"  // 🔧
```
(The `#if DEBUG` branch keeps Google's official **test** unit ids — leave those.)

### 2.4 SKAdNetwork
- [ ] `Info.plist` already has a starter `SKAdNetworkItems` list. Replace it with
      Google's current full list:
      <https://developers.google.com/admob/ios/3p-skadnetworks>

### 2.5 Interstitial cadence / policy
- Interstitial shows after every 3rd finished game (`AdManager.roundsPerInterstitial`).
- [ ] Make sure you never show an interstitial on the very first launch / mid-game —
      current logic only fires on round completion, which is compliant, but review
      against AdMob policy before submitting.

---

## 2b. Game Center (leaderboards)

The **Game Center** capability is already declared in
`WordleGame/WordleGame.entitlements` (`com.apple.developer.game-center`).
`GameCenterManager` authenticates on launch and submits two scores after every
finished game; `GameCenterView` shows the dashboard from the HUD trophy button
and from **Settings ▸ Game Center**.

- [ ] Enable **Game Center** for the App ID in the Apple Developer portal and in
      Xcode ▸ target ▸ Signing & Capabilities.
- [ ] In **App Store Connect ▸ your app ▸ Game Center**, create two leaderboards
      (type *Classic*, format *Integer*, sort *High to Low*) and localize their
      names for `en` + `hy`:

  | 🔧 Leaderboard ID (`GameCenterManager`) | Score submitted                     |
  |----------------------------------------|-------------------------------------|
  | `com.sargisgevorgyan.wordlegame.wins`         | total wins (`gamesWon`)             |
  | `com.sargisgevorgyan.wordlegame.beststreak`   | best streak (`maxStreak`)           |

- [ ] Test with a **Sandbox Apple ID** signed into Game Center on a real device
      (the Simulator can't fully exercise Game Center).
- [ ] Attach the leaderboards to the app version before submitting.

> Until the app record exists on App Store Connect **with Game Center enabled for
> a version**, `authenticate()` fails with `GKError 15` / server `5019` ("no game
> matching descriptor" / "not recognized by Game Center"). This is expected — the
> app handles it (`status = .unavailable`, Settings shows a notice) and keeps
> working. It's a signing + App Store Connect step, not a code issue.

---

## 2c. Localization (English + Armenian)

The app ships `en` and `hy` (`WordleGame/Resources/{en,hy}.lproj/`).
`developmentLanguage: en` and `knownRegions: [en, hy, Base]` are set in
`project.yml`. UI strings use `Text("…")` / `String(localized:)`;
`InfoPlist.strings` localizes the display name (`Wordy` / `ԲԱՌ-ԽԱՂ`) and the ATT
prompt. The **word‑list language** (`GameLanguage`) is a separate in‑game setting,
auto‑selected from the device locale on first launch.

- [ ] Add both languages under **App Store Connect ▸ App Information ▸ Localizable
      Information / Localizations**, and provide `hy` store metadata + screenshots
      if you want the listing shown in Armenian.
- [ ] Review the Armenian translations in `hy.lproj/Localizable.strings` with a
      native speaker before release (they were drafted, not professionally
      reviewed).
- [ ] Run the app with the scheme's *App Language → Հայերեն* (or
      `-AppleLanguages (hy)`) and check every screen for truncation.

---

## 3. In-App Purchases (StoreKit 2)

Products in code (`StoreManager.swift`):

| Product ID (🔧 must match App Store Connect) | Type          | Purpose            |
|---------------------------------------------|---------------|--------------------|
| `com.sargisgevorgyan.wordlegame.removeads`      | Non-Consumable| Remove all ads     |
| `com.sargisgevorgyan.wordlegame.hints.five`    | Consumable    | +5 hints           |
| `com.sargisgevorgyan.wordlegame.hints.twenty`  | Consumable    | +20 hints          |

- [ ] The IDs are already namespaced under the bundle id. In **App Store Connect ▸
      your app ▸ Monetization ▸ In-App Purchases**, create all three with the
      **exact** same IDs, set prices, add a localized display name + description
      (en + hy), and a review screenshot for each.
- [ ] Submit the IAPs **with the app build** (first submission) — new apps can't
      have "approved" IAPs before the app itself is approved.
- [ ] `Products.storekit` in the repo is **local testing only** (Scheme ▸ Run ▸
      Options ▸ StoreKit Configuration). It is **not** shipped and does not need to
      match production prices. Optionally clear the StoreKit Configuration in the
      **Release** scheme so the real store is used.
- [ ] Test with a **Sandbox Apple ID** (App Store Connect ▸ Users and Access ▸
      Sandbox Testers) on a real device before release.

Notes:
- Consumables (`hints.*`) are **not restorable** — that's expected. Only
  `Remove Ads` is restored by the "Restore Purchases" button.
- Server-side receipt validation is **not** implemented (StoreKit 2 on-device
  verification only). Fine for a game of this size; add a backend check if you
  later care about fraud.

---

## 4. Privacy & compliance

- [ ] **Privacy Manifest** — add `WordleGame/PrivacyInfo.xcprivacy`. Required by
      Apple, and the AdMob SDK ships its own; you must declare:
  - Tracking = **Yes** (ads use IDFA), tracking domains from AdMob,
  - Collected data types: *Device ID*, *Advertising Data*, *Purchase History*,
  - Required-reason APIs: `UserDefaults` (`CA92.1`) — the app persists stats/hints.
- [x] **App Tracking Transparency** — `NSUserTrackingUsageDescription` is in
      `Info.plist` (localized) and `TrackingAuthorization.requestIfNeeded()` shows
      the prompt on the first `.active` scene phase (`WordleGameApp`). AdMob reads
      the resulting status on its next request. If you drop ads entirely, remove
      the ATT call + key, or Apple review may flag an unused prompt.
- [ ] **App Privacy "nutrition label"** in App Store Connect — fill it to match the
      manifest (Ad data, Purchases, Identifiers, Usage Data / Crash if you add
      analytics).
- [ ] **Privacy Policy URL** — **mandatory** because the app has IAP + ads. Host one
      and put the link in App Store Connect (and ideally in Settings in-app).
- [ ] **Support URL** — mandatory.
- [ ] **Export compliance** — the app uses only standard HTTPS (no custom crypto);
      answer "No" to the non-exempt-encryption question, or add
      `ITSAppUsesNonExemptEncryption = false` to `Info.plist` to stop being asked.
- [ ] **Age rating** — set it in App Store Connect. Word game, no objectionable
      content → likely 4+, but "Third-Party Advertising" may raise it; answer the
      questionnaire honestly.

---

## 5. App assets

- [ ] **App icon** — `Assets.xcassets/AppIcon.appiconset/icon-1024.png` (1024²,
      no alpha, no rounded corners) is present. Xcode 15+ generates the smaller
      sizes automatically from this single asset. Swap it for your final art.
- [ ] **Launch screen** — currently the default (`UILaunchScreen` with an empty
      color in `Info.plist`). Add a proper launch storyboard/asset or a solid
      brand colour if you want more than a black screen.
- [ ] **App Store screenshots** — 6.7" (iPhone 15/16 Pro Max) and 6.5" are the
      minimum required sizes. Capture from the Simulator:
      `xcrun simctl io booted screenshot shot.png`.
- [ ] **Preview video** (optional).
- [ ] **Localization** — the game ships an English and an Armenian word list +
      keyboard. If you want the **App Store listing** in Armenian too, add `hy`
      metadata in App Store Connect. In-app strings are currently English-only.

---

## 6. Build settings sanity check

- [ ] Build the **Release** configuration and run once on a device.
- [ ] The determinism / test hooks (`UITESTS`, `UITEST_LANG`, `UITEST_TARGET`,
      `UITEST_HINTS` env vars, the forced-target seam in `GameViewModel.init`, the
      `forceFinishRevealForTesting` / `mergeHintsForTesting` helpers) are **all
      `#if DEBUG`** and are stripped from Release — nothing to remove, but a quick
      grep of the archived binary for `UITEST` should come up empty.
- [ ] `GENERATE_INFOPLIST_FILE = NO` — the app uses the checked-in `Info.plist`.
      Make sure every key you changed above is in that file.
- [ ] Bitcode is not required (Xcode 14+). Leave as default.
- [ ] Confirm **In-App Purchase** and **Game Center** capabilities are on the
      target (Signing & Capabilities). Google Mobile Ads needs no extra capability.

---

## 7. Testing before submission

- [ ] `xcodebuild -scheme WordleGame -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
      — the `WordleGameTests` unit suite must pass.
- [ ] Manual pass on a **real device**:
  - English + Armenian play, the ու merge (type Ո then Ւ → one `ՈՒ` tile),
  - UI language: run with *App Language → Հայերեն* and check every screen,
  - Game Center: sign in, finish a game, open the leaderboard from the HUD trophy,
  - win / lose / Play Again, stats persistence across launches,
  - hint button spends a hint; at 0 the "Get Hints" sheet appears,
  - **Remove Ads** purchase (sandbox) → banner + interstitials disappear, and the
    **PRO** badge shows; kill & relaunch → still ad-free; "Restore Purchases" works
    on a fresh install,
  - **Buy 5 / 20 hints** (sandbox) → count increases,
  - **Watch a video** → rewarded ad plays (with SDK) → +1 hint,
  - physical Bluetooth keyboard typing,
  - haptics + sound, and the sound toggle in Settings.
- [ ] AdMob: add your device as a **test device** and verify test ads render before
      switching to live unit IDs. Never tap your own live ads.

---

## 8. Archive, upload, submit

1. [ ] Xcode → *Product ▸ Scheme ▸ Edit Scheme* → **Run/Archive = Release**,
       StoreKit Configuration = **None**.
2. [ ] Select **Any iOS Device (arm64)** and *Product ▸ Archive*
       (or `xcodebuild -scheme WordleGame -sdk iphoneos archive -archivePath build/Wordy.xcarchive`).
3. [ ] Organizer → **Distribute App ▸ App Store Connect ▸ Upload**
       (or use `xcrun altool` / **Transporter**).
4. [ ] Wait for the build to finish processing in App Store Connect (~15–60 min).
5. [ ] **TestFlight** — add internal testers, smoke-test the uploaded build
       (especially IAP + ads, which behave differently from local builds).
6. [ ] Fill the App Store listing: name, subtitle, description, keywords, category
       (Games ▸ Word), screenshots, privacy label, privacy policy + support URLs,
       age rating.
7. [ ] Attach the three IAPs to the version (**"In-App Purchases" ▸ add**).
8. [ ] **App Review notes:** state that the app contains rewarded/interstitial ads
       and consumable + non-consumable IAP; no login required, so no demo account.
9. [ ] Submit for review. Typical turnaround 24–48 h.

---

## 9. After approval

- [ ] Release manually or automatically.
- [ ] In AdMob, flip from test to live ads only once the App Store build is live,
      and confirm `app-ads.txt` is being crawled (AdMob shows the status).
- [ ] Monitor Crashes (Xcode Organizer / App Store Connect) and ad fill rate.
- [ ] For updates: bump `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`, archive,
      upload, submit.

---

## Quick placeholder checklist (🔧)

| Where | What |
|-------|------|
| `project.yml` | `DEVELOPMENT_TEAM`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, GoogleMobileAds package (bundle id already set) |
| `Info.plist` | `GADApplicationIdentifier`, `SKAdNetworkItems`, (optional) `ITSAppUsesNonExemptEncryption` |
| `AdManager.swift` | Release `bannerAdUnitID` / `interstitialAdUnitID` / `rewardedAdUnitID` |
| new file | `WordleGame/PrivacyInfo.xcprivacy` |
| Apple Developer portal | App ID `com.sargisgevorgyan.wordlegame` with In-App Purchase + Game Center |
| App Store Connect | 3 IAPs + 2 Game Center leaderboards with matching IDs, en+hy metadata, privacy label, privacy-policy URL, support URL, screenshots |
| AdMob | app + 3 ad units + `app-ads.txt` |
