//
//  BannerAdView.swift
//  WordleGame
//
//  A SwiftUI wrapper around `GADBannerView`, built with
//  `UIViewControllerRepresentable`. When the GoogleMobileAds SDK is not linked
//  it collapses to an empty, zero-height view so layouts are unaffected.
//

import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds

struct BannerAdView: UIViewControllerRepresentable {
    var adUnitID: String = AdManager.bannerAdUnitID

    func makeUIViewController(context: Context) -> BannerHostController {
        BannerHostController(adUnitID: adUnitID)
    }

    func updateUIViewController(_ uiViewController: BannerHostController, context: Context) {}
}

/// Hosts the banner and reloads it for the current width (adaptive banner).
final class BannerHostController: UIViewController {
    private let adUnitID: String
    private lazy var bannerView = GADBannerView()

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBanner()
    }

    private func loadBanner() {
        let frameWidth = view.frame.inset(by: view.safeAreaInsets).width
        let width = frameWidth > 0 ? frameWidth : UIScreen.main.bounds.width
        bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        bannerView.load(GADRequest())
    }
}

#else

/// Fallback when GoogleMobileAds is not linked.
struct BannerAdView: View {
    var adUnitID: String = AdManager.bannerAdUnitID
    var body: some View { Color.clear.frame(height: 0) }
}

#endif

/// Convenience: shows the banner only when the user has NOT bought "Remove Ads".
/// Collapses to nothing when the GoogleMobileAds SDK isn't linked.
struct BannerAdContainer: View {
    let isAdFree: Bool
    var body: some View {
        #if canImport(GoogleMobileAds)
        if !isAdFree {
            BannerAdView()
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
        #else
        EmptyView()
        #endif
    }
}
