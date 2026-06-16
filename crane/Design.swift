//
//  Design.swift
//  crane
//
//  Shared design tokens: motion, metrics, surfaces, Liquid Glass.
//

import SwiftUI

// MARK: - Motion tokens

extension Animation {
    /// View-to-view transitions (input <-> history, panel resize).
    static let craneSpring = Animation.spring(response: 0.35, dampingFraction: 0.82)

    /// Hover / press / small state changes that should snap.
    static let craneSnappy = Animation.spring(response: 0.22, dampingFraction: 0.86)

    /// Opacity-only fades; matches the existing 0.18s easeInOut.
    static let craneSubtle = Animation.easeInOut(duration: 0.18)

    /// Rhythm chart hover — quick, fluid glide between bars without overshoot.
    static let craneChartHover = Animation.spring(response: 0.28, dampingFraction: 0.9)
}

// MARK: - Metric tokens

enum DesignMetrics {
    static let grid: CGFloat = 8
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24

    static let surfaceCornerRadius: CGFloat = 22
    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 10
    static let rowCornerRadius: CGFloat = 8
    static let chipCornerRadius: CGFloat = 10

    /// Icon column in list rows (arrow.up.forward needs a bit more room than 14pt).
    static let iconColumnWidth: CGFloat = 16
    /// Navigate affordance column (chevron) in dashboard recent rows.
    static let navigateColumnWidth: CGFloat = 14
    /// Delete control column in list rows.
    static let actionColumnWidth: CGFloat = 28

    /// Capture pill content height (single input row).
    static let inputRowHeight: CGFloat = 40
    /// Hint row below capture field (12px mono + key chips).
    static let hintRowHeight: CGFloat = 24
    static let hintRowMaxHeight: CGFloat = 40
    static let inputPillVerticalPadding: CGFloat = 12

    /// Unified horizontal inset for overlay surfaces (596px wide).
    static let overlayContentInset: CGFloat = 20
    /// Unified horizontal inset for dashboard (380px wide).
    static let dashboardContentInset: CGFloat = md
    static let inputPillHorizontalPadding: CGFloat = overlayContentInset

    /// Menu-bar dashboard window.
    static let dashboardWidth: CGFloat = 380
    static let dashboardHeight: CGFloat = 580
    static let dashboardFooterHeight: CGFloat = 52
    static let dashboardSectionSpacing: CGFloat = 20
    /// Writing rhythm chart — compact so entries stay the hero.
    static let dashboardActivityChartHeight: CGFloat = 64
    /// Recent entries shown on the menu-bar dashboard.
    static let dashboardRecentLimit: Int = 4

    static var dashboardScrollHeight: CGFloat {
        dashboardHeight - dashboardFooterHeight
    }

    /// Capture pill content block (input + hint rows + inner padding).
    static var capturePillHeight: CGFloat {
        inputRowHeight + 6 + hintRowHeight + inputPillVerticalPadding * 2
    }

    // MARK: Glass surfaces

    /// Transparent breathing room around glass so drop shadows follow the rounded shape.
    static let glassShadowMargin: CGFloat = 30

    /// Visible dashboard content (stat cards, scroll, footer).
    static var dashboardWindowWidth: CGFloat { dashboardWidth + glassShadowMargin * 2 }
    static var dashboardWindowHeight: CGFloat { dashboardHeight + glassShadowMargin * 2 }

    // MARK: Floating overlay glass

    static let overlayShadowMargin: CGFloat = glassShadowMargin
    /// Visible width of the capture pill / history card glass surface.
    static let overlayGlassWidth: CGFloat = 596
    /// Glass height for the capture pill.
    static var captureGlassHeight: CGFloat { capturePillHeight }
    /// Glass height for the history card.
    static let historyGlassHeight: CGFloat = 456
}

// MARK: - Environment

private struct CraneColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .dark
}

extension EnvironmentValues {
    var craneColorScheme: ColorScheme {
        get { self[CraneColorSchemeKey.self] }
        set { self[CraneColorSchemeKey.self] = newValue }
    }
}

// MARK: - Liquid Glass

enum CraneGlass {
    static func shape(cornerRadius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Primary floating controls (capture pill, history shell).
    static var interactive: Glass {
        .regular.interactive()
    }

    /// Static shells (menu-bar dashboard).
    static var regular: Glass {
        .regular
    }
}

// MARK: - Specular border

struct SpecularBorder: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: specularColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }

    private var specularColors: [Color] {
        if colorScheme == .dark {
            return [Color.craneCream.opacity(0.22), Color.craneCream.opacity(0.04)]
        }
        return [Color.craneInk.opacity(0.12), Color.craneInk.opacity(0.03)]
    }
}

extension View {
    func specularBorder(cornerRadius: CGFloat = DesignMetrics.surfaceCornerRadius) -> some View {
        modifier(SpecularBorder(cornerRadius: cornerRadius))
    }
}

// MARK: - Surface modifiers

private struct CraneCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        // Inset wash only — dashboard shell is already Liquid Glass (avoid glass-on-glass).
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(CraneColor.cardWash(for: colorScheme))
        }
    }
}

extension View {
    /// Primary overlay shell (input bar, history card). The Liquid Glass surface is
    /// rendered by the AppKit `NSGlassEffectView` that hosts the overlay, so this
    /// keeps content transparent above it and adds the specular edge for depth parity
    /// with the menu-bar dashboard.
    func craneOverlayShell(cornerRadius: CGFloat = DesignMetrics.surfaceCornerRadius) -> some View {
        background(Color.clear)
            .specularBorder(cornerRadius: cornerRadius)
    }

    /// Accent ring for focused capture shell or active panels.
    func craneAccentFocusRing(isFocused: Bool, cornerRadius: CGFloat = DesignMetrics.surfaceCornerRadius) -> some View {
        modifier(CraneAccentFocusRingModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }

    /// Dashboard stat cards and count badges — inset wash on the glass dashboard shell.
    func craneCard(cornerRadius: CGFloat = DesignMetrics.cardCornerRadius) -> some View {
        modifier(CraneCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Inset search field and hint key chips (flat fill inside a glass shell).
    func craneInputRecess(cornerRadius: CGFloat = DesignMetrics.controlCornerRadius) -> some View {
        modifier(CraneInputRecessModifier(cornerRadius: cornerRadius))
    }

    /// List row hover / emphasis highlight.
    func craneRowHighlight(
        isHighlighted: Bool,
        isEmphasized: Bool = false,
        cornerRadius: CGFloat = DesignMetrics.rowCornerRadius
    ) -> some View {
        modifier(CraneRowHighlightModifier(
            isHighlighted: isHighlighted,
            isEmphasized: isEmphasized,
            cornerRadius: cornerRadius
        ))
    }

    /// Section divider between history header and list.
    func craneDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(CraneColor.creamLine)
                .frame(height: 0.5)
                .allowsHitTesting(false)
        }
    }

    /// Menu-bar dashboard shell. SwiftUI Liquid Glass on the system MenuBarExtra window.
    func craneDashboardBackground() -> some View {
        background {
            CraneGlass.shape(cornerRadius: DesignMetrics.surfaceCornerRadius)
                .fill(.clear)
        }
        .glassEffect(
            CraneGlass.regular,
            in: CraneGlass.shape(cornerRadius: DesignMetrics.surfaceCornerRadius)
        )
        .specularBorder(cornerRadius: DesignMetrics.surfaceCornerRadius)
    }
}

private struct CraneRowHighlightModifier: ViewModifier {
    let isHighlighted: Bool
    let isEmphasized: Bool
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background {
            if isEmphasized {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CraneColor.sageSoft(for: colorScheme))
            } else if isHighlighted {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CraneColor.recessFill(for: colorScheme))
            }
        }
        .animation(.craneSnappy, value: isHighlighted)
        .animation(.craneSnappy, value: isEmphasized)
    }
}

private struct CraneInputRecessModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(CraneColor.recessFill(for: colorScheme))
        }
    }
}

private struct CraneAccentFocusRingModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(CraneColor.focusLine(for: colorScheme), lineWidth: isFocused ? 0.75 : 0)
                .animation(.craneSnappy, value: isFocused)
                .allowsHitTesting(false)
        }
    }
}
