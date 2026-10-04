//
//  StatsView.swift
//  WordleGame
//
//  Animated stat rings, backed by the persisted @AppStorage counters.
//

import SwiftUI

struct StatsView: View {
    @AppStorage(StatsKey.gamesPlayed) private var gamesPlayed = 0
    @AppStorage(StatsKey.gamesWon) private var gamesWon = 0
    @AppStorage(StatsKey.currentStreak) private var currentStreak = 0
    @AppStorage(StatsKey.maxStreak) private var maxStreak = 0

    /// Ring animation progress 0...1.
    @State private var animate = false

    private var winPct: Int { StatsStore.winPercentage(played: gamesPlayed, won: gamesWon) }

    var body: some View {
        HStack(spacing: 16) {
            StatRing(
                value: animate ? Double(winPct) / 100 : 0,
                tint: .neonGreen,
                headline: "\(winPct)%",
                caption: "Win rate"
            )
            StatRing(
                value: animate ? ringFraction(currentStreak) : 0,
                tint: .warmYellow,
                headline: "\(currentStreak)",
                caption: "Streak"
            )
            StatRing(
                value: animate ? ringFraction(maxStreak) : 0,
                tint: .auroraBlue,
                headline: "\(maxStreak)",
                caption: "Best"
            )
            StatRing(
                value: animate ? ringFraction(gamesPlayed, over: 50) : 0,
                tint: .auroraMagenta,
                headline: "\(gamesPlayed)",
                caption: "Played"
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.1)) { animate = true }
        }
    }

    private func ringFraction(_ v: Int, over: Int = 10) -> Double {
        min(1, Double(v) / Double(over))
    }
}

private struct StatRing: View {
    let value: Double
    let tint: Color
    let headline: String
    let caption: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.001, value))
                    .stroke(tint.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.7), radius: 6)
                Text(headline)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(4)
            }
            .frame(width: 58, height: 58)

            Text(caption)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}
