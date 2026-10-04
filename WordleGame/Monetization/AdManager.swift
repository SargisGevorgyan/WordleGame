//
//  AdManager.swift
//  WordleGame
//
//  Handles Google Mobile Ads (AdMob): SDK start-up + interstitial lifecycle.
//
//  The SDK is linked as a Swift package (project.yml / Xcode project):
//  https://github.com/googleads/swift-package-manager-google-mobile-ads
//  Ad references stay wrapped in `#if canImport(GoogleMobileAds)` so the code
//  still builds if the package is removed.
//
//  ⚠️  SDK version note: this file uses the classic `GAD`-prefixed API
//      (GADMobileAds / GADBannerView / GADInterstitialAd / GADRequest), which is
//      available up to Google-Mobile-Ads-SDK 11.x. v12+ renamed these symbols
//      in Swift (MobileAds / BannerView / InterstitialAd / Request). The package
//      is pinned to 11.13.0 up to (not including) 12.0.
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
    private lazy var interstitialDelegate = FullScreenDelegate(owner: self, kind: .interstitial)
    private lazy var rewardedDelegate = FullScreenDelegate(owner: self, kind: .rewarded)
    /// Completion for the rewarded ad on screen; called once, when it closes.
    private var pendingReward: ((Int) -> Void)?
    private var rewardEarned = false
    #endif

    /// Whether "Watch a video" can be offered right now.
    var canShowRewardedAd: Bool {
        #if canImport(GoogleMobileAds)
        return isRewardedAdReady
        #elseif DEBUG
        return true     // simulated in debug builds so the flow is testable
        #else
        return false
        #endif
    }

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
            ad?.fullScreenContentDelegate = self.interstitialDelegate
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
            ad?.fullScreenContentDelegate = self.rewardedDelegate
            self.rewardedAd = ad
            self.isRewardedAdReady = true
        }
        #endif
    }

    /// Presents a rewarded ad. `onReward` is called exactly once, when the ad
    /// closes, with the hint count to grant (0 if the ad could not be shown or
    /// was closed before the reward was earned).
    func showRewardedAd(onReward: @escaping (Int) -> Void) {
        #if canImport(GoogleMobileAds)
        guard pendingReward == nil else { return }   // one already on screen
        guard let rewardedAd, let root = Self.rootViewController else {
            loadRewardedAd()
            onReward(0)
            return
        }
        // A rewarded ad can only be presented once: drop it now; the next one loads when it closes.
        self.rewardedAd = nil
        isRewardedAdReady = false
        pendingReward = onReward
        rewardEarned = false
        rewardedAd.present(fromRootViewController: root) { [weak self] in
            self?.rewardEarned = true
        }
        #elseif DEBUG
        // No SDK linked: simulate a completed rewarded ad so the flow is testable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onReward(Self.hintsPerRewardedAd)
        }
        #else
        // No SDK linked in a release build: never grant hints without an ad.
        onReward(0)
        #endif
    }

    #if canImport(GoogleMobileAds)
    /// Called when the rewarded ad closes or fails to present.
    fileprivate func finishRewardedAd() {
        let completion = pendingReward
        let granted = rewardEarned ? Self.hintsPerRewardedAd : 0
        pendingReward = nil
        rewardEarned = false
        completion?(granted)
        loadRewardedAd()
    }

    fileprivate func finishInterstitial() {
        isInterstitialReady = false
        interstitial = nil
        loadInterstitial()
    }
    #endif

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
    /// One delegate per ad type, so closing one kind never resets the other.
    final class FullScreenDelegate: NSObject, GADFullScreenContentDelegate {
        enum Kind { case interstitial, rewarded }

        weak var owner: AdManager?
        let kind: Kind
        init(owner: AdManager, kind: Kind) {
            self.owner = owner
            self.kind = kind
        }

        func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
            Task { @MainActor in self.finish() }
        }

        func ad(_ ad: GADFullScreenPresentingAd,
                didFailToPresentFullScreenContentWithError error: Error) {
            print("[AdManager] \(kind) present error: \(error.localizedDescription)")
            Task { @MainActor in self.finish() }
        }

        @MainActor private func finish() {
            switch kind {
            case .interstitial: owner?.finishInterstitial()
            case .rewarded:     owner?.finishRewardedAd()
            }
        }
    }
}
#endif
