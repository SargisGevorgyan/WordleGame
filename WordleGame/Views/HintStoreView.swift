//
//  HintStoreView.swift
//  WordleGame
//
//  Shown when the player taps the hint pill with 0 hints left: watch a rewarded
//  ad for a free hint, or buy a consumable hint pack (StoreKit 2).
//

import SwiftUI
import StoreKit

struct HintStoreView: View {
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdManager
    @Environment(\.dismiss) private var dismiss

    @State private var busyProductID: String?
    @State private var watchingAd = false

    var body: some View {
        ZStack {
            Palette.backdrop.ignoresSafeArea()
            AnimatedBackground().opacity(0.6)

            VStack(spacing: 18) {
                Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 8)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.warmYellow)
                    .neonGlow(.warmYellow, radius: 12)

                Text("Out of Hints")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("You have \(game.hintsRemaining) left")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                rewardedAdRow

                if store.hintProducts.isEmpty {
                    ForEach(StoreManager.HintPack.allCases) { pack in
                        packRow(title: "\(pack.hints) Hints", price: pack.fallbackPrice,
                                enabled: false, action: {})
                    }
                    Text("Add a StoreKit configuration (Products.storekit) to enable purchases.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                } else {
                    ForEach(store.hintProducts) { product in
                        packRow(
                            title: "\(store.hintCount(for: product)) Hints",
                            price: product.displayPrice,
                            enabled: busyProductID == nil,
                            loading: busyProductID == product.id
                        ) {
                            Task { await buy(product) }
                        }
                    }
                }

                if case .failed(let message) = store.state {
                    Text(message).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                }

                Button("Maybe later") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)

                Spacer(minLength: 4)
            }
            .padding(22)
            .frame(maxWidth: 420)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Rewarded ad row

    private var rewardedAdRow: some View {
        Button {
            watchingAd = true
            ads.showRewardedAd { granted in
                watchingAd = false
                if granted > 0 {
                    game.addHints(granted)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch a video").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("+\(AdManager.hintsPerRewardedAd) hint · free")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if watchingAd { ProgressView().tint(.white) }
                else { Image(systemName: "gift.fill").foregroundStyle(Color.neonGreen) }
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Palette.playAgainGradient.opacity(0.9),
                       in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .neonGreen.opacity(0.5), radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(watchingAd || !ads.canShowRewardedAd)
        .opacity(ads.canShowRewardedAd || watchingAd ? 1 : 0.5)
        .accessibilityIdentifier("watch-ad-button")
        .accessibilityLabel("Watch a video")
    }

    // MARK: - Pack row

    private func packRow(title: LocalizedStringKey, price: String, enabled: Bool,
                         loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(Color.warmYellow)
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                if loading { ProgressView().tint(.white) }
                else { Text(verbatim: price).font(.subheadline.weight(.bold)) }
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity)
            .glass(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private func buy(_ product: Product) async {
        busyProductID = product.id
        let ok = await store.purchaseHints(product)
        busyProductID = nil
        if ok { dismiss() }
    }
}
