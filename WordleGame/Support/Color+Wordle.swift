//
//  Color+Wordle.swift
//  WordleGame
//
//  Premium dark-indigo palette. The screen is designed dark-first
//  (`RootView` locks `.dark`), so these are fixed values, not adaptive.
//

import SwiftUI

extension Color {

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    // MARK: Backdrop
    static let indigoTop    = Color(hex: 0x1C1B4B)
    static let indigoMid    = Color(hex: 0x121233)
    static let indigoDeep   = Color(hex: 0x08081C)
    static let auroraPurple  = Color(hex: 0x7C3AED)
    static let auroraBlue    = Color(hex: 0x2563EB)
    static let auroraMagenta = Color(hex: 0xDB2777)
    static let auroraTeal    = Color(hex: 0x14B8A6)

    // MARK: Status (vibrant, glow-friendly)
    static let neonGreen  = Color(hex: 0x2DE38B)
    static let warmYellow = Color(hex: 0xF4C13B)
    static let glassSlate = Color(hex: 0x3A3B52)

    // MARK: High contrast (colour-blind friendly: orange = right spot, blue = wrong spot)
    static let contrastOrange = Color(hex: 0xF5793A)
    static let contrastBlue   = Color(hex: 0x85C0F9)

    // MARK: Glass / text
    static let glassFill    = Color.white.opacity(0.06)
    static let glassStroke  = Color.white.opacity(0.18)
    static let keyIdleFill  = Color.white.opacity(0.10)
    static let primaryText  = Color.white
    static let secondaryText = Color.white.opacity(0.55)

    // MARK: Back-compat tokens used across the codebase
    static let wordleGreen  = neonGreen
    static let wordleYellow = warmYellow
    static let wordleGray   = glassSlate
    static let wordleAccent = neonGreen
    static let wordleTileEmpty   = Color.white.opacity(0.05)
    static let wordleKeyIdle     = keyIdleFill
    static let wordleBorderIdle  = Color.white.opacity(0.12)
    static let wordleBorderActive = Color.white.opacity(0.45)
    static let wordlePrimaryText = primaryText
    static let wordleBackground  = indigoDeep
}

// MARK: - Reusable gradients

enum Palette {
    static var backdrop: LinearGradient {
        LinearGradient(
            colors: [.indigoTop, .indigoMid, .indigoDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var glassStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.35), .white.opacity(0.05), .white.opacity(0.15)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var enterGradient: LinearGradient {
        LinearGradient(colors: [.auroraPurple, .auroraBlue],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var playAgainGradient: LinearGradient {
        LinearGradient(colors: [.neonGreen, .auroraTeal],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var proGradient: LinearGradient {
        LinearGradient(colors: [.warmYellow, .auroraMagenta],
                       startPoint: .leading, endPoint: .trailing)
    }
}
