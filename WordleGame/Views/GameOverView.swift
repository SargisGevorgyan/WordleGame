//
//  GameOverView.swift
//  WordleGame
//
//  Frosted end-of-game modal with bouncy physics, animated stat rings and a
//  gradient "Play Again" button.
//

import SwiftUI

struct GameOverView: View {
    let didWin: Bool
    let targetWord: String
    let onPlayAgain: () -> Void

    @State private var appear = false

    private let headline: (won: LocalizedStringKey, lost: LocalizedStringKey) = ("BRILLIANT", "SO CLOSE")
    private let subtitle: (won: LocalizedStringKey, lost: LocalizedStringKey) = ("You cracked it", "The word was")

    var body: some View {
        VStack(spacing: 22) {
            Text(didWin ? headline.won : headline.lost)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white)
                .neonGlow(didWin ? .neonGreen : .auroraMagenta, radius: 14)

            VStack(spacing: 4) {
                Text(didWin ? subtitle.won : subtitle.lost)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Text(verbatim: targetWord.uppercased())
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .neonGlow(.warmYellow, radius: 8, strength: 0.6)
            }

            StatsView()

            Button(action: onPlayAgain) {
                Text("Play Again")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Palette.playAgainGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.black.opacity(0.85))
                    .shadow(color: .neonGreen.opacity(0.6), radius: 14, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(26)
        .frame(maxWidth: 360)
        .glass(cornerRadius: 26)
        .padding(.horizontal, 28)
        .scaleEffect(appear ? 1 : 0.8)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
        }
    }
}
