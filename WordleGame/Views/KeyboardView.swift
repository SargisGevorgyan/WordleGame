//
//  KeyboardView.swift
//  WordleGame
//
//  Frosted-glass KDWIN / QWERTY keyboard. Letter keys glow with their latest
//  hint colour; DELETE (⌫) and ENTER (↵) are larger with an action gradient.
//

import SwiftUI

struct KeyboardView: View {
    let rows: [[String]]
    let compact: Bool
    /// Keyed by token string ("A" … or the Armenian "ՈՒ").
    let hints: [String: LetterEvaluation]
    let onKey: (String) -> Void
    let onEnter: () -> Void
    let onDelete: () -> Void

    private var letterSize: CGFloat { compact ? 15 : 18 }
    private var rowSpacing: CGFloat { compact ? 5 : 6 }
    private var keySpacing: CGFloat { compact ? 3.5 : 5 }
    private var keyHeight: CGFloat { compact ? 48 : 54 }
    private var actionWidth: CGFloat { compact ? 52 : 60 }

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: keySpacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, token in
                        keyButton(for: token)
                    }
                }
            }
        }
        .padding(10)
        .glass(cornerRadius: 22)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func keyButton(for token: String) -> some View {
        switch token.uppercased() {
        case "ENTER":
            ActionKey(symbol: "return", identifier: "key-ENTER", accessibilityLabel: "Enter",
                      gradient: Palette.enterGradient, glow: .auroraBlue,
                      width: actionWidth, height: keyHeight, action: onEnter)
        case "DELETE", "DEL":
            ActionKey(symbol: "delete.left", identifier: "key-DELETE", accessibilityLabel: "Delete",
                      gradient: Palette.proGradient, glow: .auroraMagenta,
                      width: actionWidth, height: keyHeight, action: onDelete)
        default:
            // A single letter ("Ա") or, if the layout defines one, a digraph ("ՈՒ").
            let evaluation = hints[token.uppercased()]
            LetterKey(
                token: token,
                evaluation: evaluation,
                fontSize: letterSize,
                height: keyHeight,
                action: { onKey(token) }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: evaluation)
        }
    }
}

// MARK: - Press feedback (ButtonStyle — never fights the button's own tap)

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Letter key

private struct LetterKey: View {
    let token: String
    let evaluation: LetterEvaluation?
    let fontSize: CGFloat
    let height: CGFloat
    let action: () -> Void

    @AppStorage(LetterEvaluation.highContrastKey) private var highContrast = false

    private var isHinted: Bool { evaluation != nil }
    private var hintColor: Color { evaluation?.fillColor(highContrast: highContrast) ?? .clear }

    var body: some View {
        Button(action: action) {
            Text(token)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isHinted
                                  ? AnyShapeStyle(hintColor.gradient)
                                  : AnyShapeStyle(.ultraThinMaterial))
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(isHinted ? 0.12 : 0.06))
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Palette.glassStrokeGradient, lineWidth: 1)
                    }
                }
                .shadow(color: isHinted ? hintColor.opacity(0.55) : .clear, radius: 8)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityIdentifier("key-\(token)")
    }
}

// MARK: - Action key (ENTER / DELETE)

private struct ActionKey: View {
    let symbol: String
    let identifier: String
    let accessibilityLabel: LocalizedStringKey
    let gradient: LinearGradient
    let glow: Color
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: width, height: height)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(gradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
                .shadow(color: glow.opacity(0.6), radius: 10)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
    }
}
