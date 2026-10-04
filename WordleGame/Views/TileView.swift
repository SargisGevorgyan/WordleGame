//
//  TileView.swift
//  WordleGame
//
//  Premium 3D-feel board tile:
//   • frosted-glass empty state with depth shadow + top highlight,
//   • pop-in bump when a letter is typed,
//   • snappy spring 3D flip on reveal with a vibrant glowing status colour.
//

import SwiftUI

struct TileView: View {
    let tile: Tile
    let rowIndex: Int
    let columnIndex: Int

    private static let flipSpring = Animation.spring(response: 0.45, dampingFraction: 0.6)
    private static let popSpring  = Animation.spring(response: 0.30, dampingFraction: 0.45)

    @State private var flip: Double = 0          // 0 → 180
    @State private var faceRevealed = false
    @State private var pop = false

    private var isRevealed: Bool {
        switch tile.evaluation {
        case .correct, .present, .absent: return true
        default: return false
        }
    }

    private var statusColor: Color { tile.evaluation.fillColor }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(faceRevealed
                      ? AnyShapeStyle(statusColor.gradient)
                      : AnyShapeStyle(LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom)))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    faceRevealed ? AnyShapeStyle(Color.white.opacity(0.45))
                                 : AnyShapeStyle(LinearGradient(
                                       colors: [.white.opacity(0.5), .white.opacity(0.12)],
                                       startPoint: .top, endPoint: .bottom)),
                    lineWidth: 1.2
                )

            Text(tile.displayText)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(faceRevealed || tile.letter != nil ? Color.white : Color.secondaryText)
                .shadow(color: faceRevealed ? statusColor.opacity(0.9) : .clear, radius: 6)
                .padding(4)
                .rotation3DEffect(.degrees(faceRevealed ? 180 : 0), axis: (x: 1, y: 0, z: 0))
        }
        .frame(width: 58, height: 58)
        .rotation3DEffect(.degrees(flip), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .scaleEffect(pop ? 1.12 : 1.0)
        .shadow(color: .black.opacity(0.35), radius: 5, y: 4)
        .shadow(color: faceRevealed ? statusColor.opacity(0.55) : .clear, radius: 12)
        .onChange(of: tile.letter) { _, newValue in
            guard newValue != nil, !isRevealed else { return }
            withAnimation(Self.popSpring) { pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(Self.popSpring) { pop = false }
            }
        }
        .onChange(of: isRevealed) { _, revealed in
            revealed ? runFlip() : resetFace()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("tile-\(rowIndex)-\(columnIndex)")
        .accessibilityValue("\(tile.displayText)|\(tile.evaluation.name)")
    }

    private func runFlip() {
        let delay = Double(columnIndex) * 0.18
        withAnimation(Self.flipSpring.delay(delay)) { flip = 180 }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.16) {
            withAnimation(.easeOut(duration: 0.12)) { faceRevealed = true }
        }
    }

    private func resetFace() {
        flip = 0
        faceRevealed = false
    }
}
