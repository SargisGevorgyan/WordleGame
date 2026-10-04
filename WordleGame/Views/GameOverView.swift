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
    let meaning: String?
    /// Set for the daily game: shows the countdown to the next word, and the
    /// main button switches to free play.
    var puzzleNumber: Int? = nil
    var shareText: String = ""
    let onPlayAgain: () -> Void

    @State private var appear = false

    private let headline: (won: LocalizedStringKey, lost: LocalizedStringKey) = ("BRILLIANT", "SO CLOSE")
    private let subtitle: (won: LocalizedStringKey, lost: LocalizedStringKey) = ("You cracked it", "The word was")

    var body: some View {
        VStack(spacing: 22) {
            if let puzzleNumber {
                Text("Daily #\(puzzleNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

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
                if let meaning {
                    Text(verbatim: meaning)
                        .font(.callout)
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityLabel(Text("Meaning") + Text(verbatim: ": \(meaning)"))
                        .accessibilityIdentifier("word-meaning")
                }
            }

            StatsView()

            if puzzleNumber != nil {
                VStack(spacing: 2) {
                    Text("Next word in")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(timerInterval: Date.now...DailyPuzzle.nextWordDate(), countsDown: true)
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }

            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(Color.neonGreen)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.neonGreen, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("share-result")

            Button(action: onPlayAgain) {
                Text(puzzleNumber == nil ? LocalizedStringKey("Play Again") : "Free play")
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
