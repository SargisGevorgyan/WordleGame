//
//  SplashView.swift
//  WordleGame
//
//  Brief animated intro shown over `RootView` at launch. It starts on exactly
//  what the system launch screen shows (Info.plist `UILaunchScreen`: the
//  `LaunchBackground` colour with the centred `LaunchLogo` tiles), so the
//  hand-off is seamless; then the tiles pop, the title glows in and the whole
//  overlay fades away. Android mirrors this in `ui/Splash.kt`.
//

import SwiftUI

struct SplashView: View {
    /// Called once the intro has played; the caller removes the overlay.
    let onFinished: () -> Void

    // Same geometry as LaunchLogo.svg (93pt square: 2×2 tiles, 19:4 tile:gap).
    private static let tileSize: CGFloat = 42
    private static let tileGap: CGFloat = 9
    private static let logoSize: CGFloat = tileSize * 2 + tileGap

    private let tileColors: [Color] = [.neonGreen, .warmYellow, .glassSlate, .neonGreen]

    @State private var bumped = [false, false, false, false]
    @State private var showTitle = false

    private var title: String {
        switch GameLanguage.current {
        case .english:  return "WORDY"
        case .armenian: return "ԲԱՌ-ԽԱՂ"
        }
    }

    var body: some View {
        ZStack {
            Color.indigoDeep.ignoresSafeArea()

            logo

            Text(title)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(
                    LinearGradient(colors: [.white, .neonGreen, .auroraTeal],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .neonGreen.opacity(0.9), radius: 10)
                .shadow(color: .auroraPurple.opacity(0.55), radius: 30)
                .opacity(showTitle ? 1 : 0)
                .offset(y: Self.logoSize / 2 + (showTitle ? 40 : 56))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task { await play() }
    }

    private var logo: some View {
        VStack(spacing: Self.tileGap) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: Self.tileGap) {
                    ForEach(0..<2, id: \.self) { column in
                        let index = row * 2 + column
                        RoundedRectangle(cornerRadius: Self.tileSize * 3 / 19, style: .continuous)
                            .fill(tileColors[index])
                            .frame(width: Self.tileSize, height: Self.tileSize)
                            .shadow(color: tileColors[index].opacity(bumped[index] ? 0.9 : 0), radius: 12)
                            .scaleEffect(bumped[index] ? 1.14 : 1)
                    }
                }
            }
        }
        .frame(width: Self.logoSize, height: Self.logoSize)
    }

    @MainActor
    private func play() async {
        // The first frame equals the launch image; each tile then bumps in turn.
        for index in bumped.indices {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { bumped[index] = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bumped[index] = false }
        }
        withAnimation(.easeOut(duration: 0.45)) { showTitle = true }
        try? await Task.sleep(for: .milliseconds(850))
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
}
