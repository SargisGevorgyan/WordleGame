//
//  ShakeEffect.swift
//  WordleGame
//
//  A horizontal shake `GeometryEffect`, animated by changing `animatableData`.
//

import SwiftUI

struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travelDistance * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    /// Plays one shake whenever `token` changes.
    func shake(token: Int) -> some View {
        modifier(ShakeOnChange(token: token))
    }
}

private struct ShakeOnChange: ViewModifier {
    let token: Int
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: progress))
            .onChange(of: token) { _, newValue in
                guard newValue != 0 else { progress = 0; return }
                progress = 0
                withAnimation(.linear(duration: 0.5)) { progress = 1 }
            }
    }
}
