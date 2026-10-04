//
//  AdManager.swift
//  WordleGame
//
//  Handles Google Mobile Ads (AdMob): SDK start-up + interstitial lifecycle.
//
//  Every ad reference is wrapped in `#if canImport(GoogleMobileAds)`, so the
//  app builds and runs with ZERO external dependencies. To switch real ads on:
//
//    1. Xcode > File > Add Package Dependencies…
//       https://github.com/googleads/googleads-mobile-ios-sdk  (see note below)
//    2. Re-run `xcodegen generate` (or add the framework to the target).
//
//  ⚠️  SDK version note: this file uses the classic `GAD`-prefixed API
//      (GADMobileAds / GADBannerView / GADInterstitialAd / GADRequest), which is
//      available up to Google-Mobile-Ads-SDK 11.x. v12+ renamed these symbols
//      in Swift (MobileAds / BannerView / InterstitialAd / Request). Pin to
//      "11.13.0" for a drop-in build, or rename the symbols for v12+.
//

import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdManager: ObservableObject {

    // MARK: - Ad Unit IDs

    #if DEBUG
    /// Google's official test IDs — safe to ship in debug, work in the Simulator.
    static let bannerAdUnitID       = "ca-app-pub-3940256099942544/2934735716"
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedAdUnitID     = "ca-app-pub-3940256099942544/1712485313"
    #else
    /// 🔧 Replace with your real AdMob unit IDs for the App Store build.
    static let bannerAdUnitID       = "ca-app-pub-0000000000000000/0000000000"
    static let interstitialAdUnitID = "ca-app-pub-0000000000000000/1111111111"
    static let rewardedAdUnitID     = "ca-app-pub-0000000000000000/2222222222"
    #endif

    /// Show an interstitial after every Nth completed game.
    static let roundsPerInterstitial = 3
    /// Hints granted for watching one rewarded ad.
    static let hintsPerRewardedAd = 1

    // MARK: - State

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedAdReady = false
    private var completedRounds = 0

    #if canImport(GoogleMobileAds)
    private var interstitial: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    private lazy var fullScreenDelegate = FullScreenDelegate(owner: self)
    #endif

    // MARK: - Bootstrap

    /// Call once at launch (from `WordleGameApp.init`).
    static func bootstrap() {
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif
    }

    init() {
        loadInterstitial()
        loadRewardedAd()
    }

    // MARK: - Interstitial

    func loadInterstitial() {
        #if canImport(GoogleMobileAds)
        let request = GADRequest()
        GADInterstitialAd.load(
            withAdUnitID: Self.interstitialAdUnitID,
            request: request
        ) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("[AdManager] Interstitial failed to load: \(error.localizedDescription)")
                self.isInterstitialReady = false
                return
            }
            ad?.fullScreenContentDelegate = self.fullScreenDelegate
            self.interstitial = ad
            self.isInterstitialReady = true
        }
        #endif
    }

    /// Called by the game once per finished round.
    func registerRoundCompleted(isAdFree: Bool) {
        completedRounds += 1
        guard !isAdFree else { return }
        if completedRounds % Self.roundsPerInterstitial == 0 {
            showInterstitial(isAdFree: isAdFree)
        }
    }

    func showInterstitial(isAdFree: Bool) {
        guard !isAdFree else { return }
        #if canImport(GoogleMobileAds)
        guard let interstitial, let root = Self.rootViewController else {
            loadInterstitial()
            return
        }
        interstitial.present(fromRootViewController: root)
        #endif
    }

    // MARK: - Rewarded ad (earn hints)

    func loadRewardedAd() {
        #if canImport(GoogleMobileAds)
        GADRewardedAd.load(
            withAdUnitID: Self.rewardedAdUnitID,
            request: GADRequest()
        ) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("[AdManager] Rewarded failed to load: \(error.localizedDescription)")
                self.isRewardedAdReady = false
                return
            }
            ad?.fullScreenContentDelegate = self.fullScreenDelegate
            self.rewardedAd = ad
            self.isRewardedAdReady = true
        }
        #endif
    }

    /// Presents a rewarded ad. `onReward` is called with the hint count to grant
    /// once the user has earned the reward (0 if the ad could not be shown).
    func showRewardedAd(onReward: @escaping (Int) -> Void) {
        #if canImport(GoogleMobileAds)
        guard let rewardedAd, let root = Self.rootViewController else {
            loadRewardedAd()
            onReward(0)
            return
        }
        rewardedAd.present(fromRootViewController: root) { [weak self] in
            onReward(Self.hintsPerRewardedAd)
            self?.rewardedAd = nil
            self?.isRewardedAdReady = false
            self?.loadRewardedAd()
        }
        #else
        // No SDK linked: simulate a completed rewarded ad so the flow is testable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onReward(Self.hintsPerRewardedAd)
        }
        #endif
    }

    // MARK: - Helpers

    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

// MARK: - Full screen content delegate

#if canImport(GoogleMobileAds)
extension AdManager {
    final class FullScreenDelegate: NSObject, GADFullScreenContentDelegate {
        weak var owner: AdManager?
        init(owner: AdManager) { self.owner = owner }

        func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
            Task { @MainActor in
                self.owner?.isInterstitialReady = false
                self.owner?.interstitial = nil
                self.owner?.loadInterstitial()
            }
        }

        func ad(_ ad: GADFullScreenPresentingAd,
                didFailToPresentFullScreenContentWithError error: Error) {
            print("[AdManager] Interstitial present error: \(error.localizedDescription)")
            Task { @MainActor in self.owner?.loadInterstitial() }
        }
    }
}
#endif
