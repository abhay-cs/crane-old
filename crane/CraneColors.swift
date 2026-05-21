//
//  CraneColors.swift
//  crane
//
//  Brand palette from landing/styles.css — adaptive light/dark assets.
//  Asset names map to generated `Color.craneInk` etc. when the catalog
//  provides Swift symbols; this enum is the stable call site.
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
    static let warning = Color("CraneWarning")
    static let accent = Color.accentColor

    /// Filled controls (segment pill, primary buttons). Same hue as `accent`.
    static func accentFill(for scheme: ColorScheme) -> Color {
        accent
    }

    /// Hover, focus, and selected backgrounds — not static card fills.
    static func accentSoft(for scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.22 : 0.10)
    }

    /// Selection rings and focused-field outlines (mirrors landing `--accent-line`).
    static func accentLine(for scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.40 : 0.28)
    }

    /// Brief luminous pulse on save / active indicators.
    static func accentGlow(for scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.35 : 0.25)
    }

    static let creamLine = cream.opacity(0.07)
    static let inkLine = ink.opacity(0.08)

    /// Elevated card / badge wash — warm in dark, ink in light.
    static func cardWash(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cream.opacity(0.04) : ink.opacity(0.04)
    }

    /// Capture-field insertion point: cream in dark mode, black in light mode.
    static func caret(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cream : .black
    }
}
