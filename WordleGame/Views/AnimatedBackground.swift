//
//  AnimatedBackground.swift
//  WordleGame
//
//  Deep dark-indigo gradient with slow ambient aurora glows and a few drifting
//  particles behind everything. Driven by a single TimelineView clock.
//

import SwiftUI

struct AnimatedBackground: View {
    private let blobs: [Blob] = [
        Blob(color: .auroraPurple,  size: 460, base: CGPoint(x: 0.15, y: 0.15), speed: 0.05, radius: 0.18),
        Blob(color: .auroraBlue,    size: 520, base: CGPoint(x: 0.85, y: 0.30), speed: 0.037, radius: 0.22),
        Blob(color: .auroraMagenta, size: 400, base: CGPoint(x: 0.70, y: 0.85), speed: 0.045, radius: 0.20),
        Blob(color: .auroraTeal,    size: 360, base: CGPoint(x: 0.20, y: 0.80), speed: 0.03, radius: 0.16)
    ]

    private let particles: [Particle] = (0..<16).map { _ in Particle.random() }

    /// Continuous animation makes XCUITest wait forever for the app to idle, so
    /// UI-test runs get a static (still gorgeous) backdrop.
    private var animates: Bool {
        ProcessInfo.processInfo.environment["UITESTS"] != "1"
    }

    var body: some View {
        if animates {
            TimelineView(.animation) { timeline in
                canvas(t: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(t: 0)
        }
    }

    private func canvas(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Palette.backdrop

                ForEach(Array(blobs.enumerated()), id: \.offset) { _, blob in
                    Circle()
                        .fill(blob.color)
                        .frame(width: blob.size, height: blob.size)
                        .blur(radius: 120)
                        .opacity(0.42)
                        .position(blob.position(in: size, t: t))
                        .blendMode(.screen)
                }

                if animates {   // skip the particle layer in UI tests (lighter scene)
                    ForEach(Array(particles.enumerated()), id: \.offset) { _, particle in
                        Circle()
                            .fill(.white)
                            .frame(width: particle.size, height: particle.size)
                            .opacity(particle.opacity(t))
                            .position(particle.position(in: size, t: t))
                            .blur(radius: 0.5)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct Blob {
    let color: Color
    let size: CGFloat
    let base: CGPoint          // 0...1 fractional anchor
    let speed: Double
    let radius: Double         // fractional drift radius

    func position(in size: CGSize, t: TimeInterval) -> CGPoint {
        let dx = cos(t * speed * .pi) * radius * size.width
        let dy = sin(t * speed * .pi * 1.3) * radius * size.height
        return CGPoint(x: base.x * size.width + dx, y: base.y * size.height + dy)
    }
}

private struct Particle {
    let x: Double
    let size: CGFloat
    let period: Double
    let phase: Double

    static func random() -> Particle {
        Particle(
            x: .random(in: 0.04...0.96),
            size: .random(in: 1.5...3.5),
            period: .random(in: 14...30),
            phase: .random(in: 0...1)
        )
    }

    private func progress(_ t: TimeInterval) -> Double {
        (t / period + phase).truncatingRemainder(dividingBy: 1)
    }

    func position(in size: CGSize, t: TimeInterval) -> CGPoint {
        let p = progress(t)
        let drift = sin((p + phase) * .pi * 2) * 14
        return CGPoint(x: x * size.width + drift, y: (1 - p) * size.height)
    }

    func opacity(_ t: TimeInterval) -> Double {
        let p = progress(t)
        return (sin(p * .pi)) * 0.5      // fade in/out over the travel
    }
}
