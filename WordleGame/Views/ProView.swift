//
//  ProView.swift
//  WordleGame
//
//  "Wordy Pro" paywall: monthly / yearly auto-renewable subscription (no ads +
//  unlimited hints), with the one-time Remove Ads purchase as the cheaper option.
//  Shows the renewal terms and Terms / Privacy links App Review requires for
//  subscriptions.
//

import SwiftUI
import StoreKit

struct ProView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: StoreManager.ProPlan = .yearly
    @State private var busy = false
    @State private var showManageSubscriptions = false

    var body: some View {
        ZStack {
            Palette.backdrop.ignoresSafeArea()
            AnimatedBackground().opacity(0.6)

            ScrollView {
                VStack(spacing: 16) {
                    Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 8)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.warmYellow)
                        .neonGlow(.warmYellow, radius: 12)

                    Text("Wordy Pro")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 10) {
                        feature("nosign", "No ads")
                        feature("lightbulb.fill", "Unlimited hints")
                    }
                    .padding(.vertical, 4)

                    if store.isPro {
                        proActiveSection
                    } else {
                        planPicker
                        subscribeButton
                        if !store.ownsRemoveAds { removeAdsRow }
                    }

                    if case .failed(let message) = store.state {
                        Text(message).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))

                    legal

                    Button("Maybe later") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(22)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .onChange(of: store.isPro) { _, isPro in
            if isPro { Haptics.shared.notify(.success) }
        }
    }

    // MARK: - Sections

    private func feature(_ icon: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.neonGreen)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(StoreManager.ProPlan.allCases) { plan in
                Button { selectedPlan = plan } label: {
                    HStack {
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPlan == plan ? Color.neonGreen : .white.opacity(0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan == .monthly ? LocalizedStringKey("Monthly") : LocalizedStringKey("Yearly"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            if plan == .yearly, let savings = yearlySavingsPercent {
                                Text("Save \(savings)%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.neonGreen)
                            }
                        }
                        Spacer()
                        Text(verbatim: store.proDisplayPrice(plan))
                            .font(.subheadline.weight(.bold))
                        Text(plan == .monthly ? LocalizedStringKey("/ month") : LocalizedStringKey("/ year"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .glass(cornerRadius: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selectedPlan == plan ? Color.neonGreen : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pro-plan-\(plan == .monthly ? "monthly" : "yearly")")
            }
        }
    }

    private var subscribeButton: some View {
        Button {
            Task {
                busy = true
                await store.purchasePro(selectedPlan)
                busy = false
                if store.isPro { dismiss() }
            }
        } label: {
            HStack {
                if busy { ProgressView().tint(Color.black.opacity(0.85)) }
                Text("Continue")
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Palette.playAgainGradient, in: Capsule())
            .shadow(color: .neonGreen.opacity(0.5), radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(busy || store.proProducts.isEmpty)
        .opacity(store.proProducts.isEmpty ? 0.5 : 1)
        .accessibilityIdentifier("pro-subscribe-button")
    }

    private var removeAdsRow: some View {
        Button {
            Task { await store.purchaseRemoveAds() }
        } label: {
            Text("Just remove ads · \(store.removeAdsDisplayPrice) once")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
        .disabled(store.state == .purchasing || store.removeAdsProduct == nil)
    }

    private var proActiveSection: some View {
        VStack(spacing: 10) {
            Label("You're Pro. Thank you!", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.neonGreen)
            Button("Manage Subscription") { showManageSubscriptions = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glass(cornerRadius: 14)
    }

    private var legal: some View {
        VStack(spacing: 6) {
            Text("Payment is charged to your Apple ID. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel it in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: StoreManager.termsOfUseURL)
                Link("Privacy Policy", destination: StoreManager.privacyPolicyURL)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Helpers

    /// "Save 58%" on the yearly plan vs. 12 monthly payments (only when both prices are loaded).
    private var yearlySavingsPercent: Int? {
        guard let monthly = store.proProduct(.monthly)?.price,
              let yearly = store.proProduct(.yearly)?.price,
              monthly > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: yearly / (monthly * 12)).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent > 0 ? percent : nil
    }
}
