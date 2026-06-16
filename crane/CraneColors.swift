//
//  CraneColors.swift
//  crane
//
//  Brand palette from landing/styles.css — adaptive light/dark assets.
//  Journal system: warm neutrals + one accent (Write) + semantic link/thought + sage.
//

import SwiftUI

enum CraneColor {
    static let ink = Color("CraneInk")
    static let inkSecondary = Color("CraneInkSecondary")
    static let inkTertiary = Color("CraneInkTertiary")
    static let cream = Color("CraneCream")
    static let surface = Color("CraneSurface")
    static let thought = Color("CraneThought")
    static let link = Color("CraneLink")
    static let sage = Color("CraneSage")
    static let warning = Color("CraneWarning")

    /// Primary accent — reserve for the Write CTA and nothing else filled.
    static let accent = Color.accentColor

    // MARK: Accent (Write button only)

    static func accentFill(for scheme: ColorScheme) -> Color {
        accent
    }

    static func accentGlow(for scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.35 : 0.25)
    }

    // MARK: Semantic

    static func linkLine(for scheme: ColorScheme) -> Color {
        link.opacity(scheme == .dark ? 0.45 : 0.35)
    }

    // MARK: Sage (tags, empty states)

    static func sageSoft(for scheme: ColorScheme) -> Color {
        sage.opacity(scheme == .dark ? 0.16 : 0.12)
    }

    static func sageLine(for scheme: ColorScheme) -> Color {
        sage.opacity(scheme == .dark ? 0.38 : 0.30)
    }

    // MARK: Neutral structure

    static func focusLine(for scheme: ColorScheme) -> Color {
        cream.opacity(scheme == .dark ? 0.22 : 0.16)
    }

    static func recessFill(for scheme: ColorScheme) -> Color {
        ink.opacity(scheme == .dark ? 0.06 : 0.05)
    }

    static let creamLine = cream.opacity(0.12)
    static let inkLine = ink.opacity(0.08)

    static func cardWash(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cream.opacity(0.04) : ink.opacity(0.04)
    }

    static func caret(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cream : .black
    }
}
