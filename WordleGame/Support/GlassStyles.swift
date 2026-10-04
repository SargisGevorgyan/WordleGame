//
//  GlassStyles.swift
//  WordleGame
//
//  Glassmorphism 2.0 helpers: translucent material fills with a thin vibrant
//  stroke, plus a neon glow for the title.
//
//  NOTE: every decorative layer lives inside `.background { … }` and is marked
//  `.allowsHitTesting(false)`, so glass panels never intercept taps meant for
//  the buttons they sit behind.
//

import SwiftUI

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    var strokeOpacity: Double = 1
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Palette.glassStrokeGradient, lineWidth: 1)
                        .opacity(strokeOpacity)
                }
                .allowsHitTesting(false)
            }
            .shadow(color: shadow ? .black.opacity(0.35) : .clear, radius: 18, y: 10)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 18, strokeOpacity: Double = 1, shadow: Bool = true) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, shadow: shadow))
    }

    /// Layered coloured glows — used for the title and for revealed tiles/keys.
    func neonGlow(_ color: Color, radius: CGFloat = 10, strength: Double = 0.9) -> some View {
        self
            .shadow(color: color.opacity(strength), radius: radius / 2)
            .shadow(color: color.opacity(strength * 0.7), radius: radius)
            .shadow(color: color.opacity(strength * 0.4), radius: radius * 2)
    }
}
