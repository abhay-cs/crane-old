//
//  Design.swift
//  crane
//
//  Shared design tokens: motion, metrics, surfaces, specular borders.
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

    /// Icon column in list rows.
    static let iconColumnWidth: CGFloat = 14
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
    static let inputPillHorizontalPadding: CGFloat = 18

    /// Menu-bar dashboard window.
    static let dashboardWidth: CGFloat = 380
    static let dashboardHeight: CGFloat = 580
    static let dashboardFooterHeight: CGFloat = 52
    static let dashboardSectionSpacing: CGFloat = 20

    static var dashboardScrollHeight: CGFloat {
        dashboardHeight - dashboardFooterHeight
    }
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
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CraneColor.cardWash(for: colorScheme))
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.regularMaterial)
                    }
            }
            .specularBorder(cornerRadius: cornerRadius)
    }
}

extension View {
    /// Primary overlay shell (input bar, history card). Material + surface tint + specular.
    func craneOverlayShell(cornerRadius: CGFloat = DesignMetrics.surfaceCornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.craneSurface.opacity(0.35))
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
        .specularBorder(cornerRadius: cornerRadius)
    }

    /// Accent ring for focused capture shell or active panels.
    func craneAccentFocusRing(isFocused: Bool, cornerRadius: CGFloat = DesignMetrics.surfaceCornerRadius) -> some View {
        modifier(CraneAccentFocusRingModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }

    /// Dashboard stat cards and count badges — neutral material, not accent wash.
    func craneCard(cornerRadius: CGFloat = DesignMetrics.cardCornerRadius) -> some View {
        modifier(CraneCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Inset search field and hint key chips.
    func craneInputRecess(cornerRadius: CGFloat = DesignMetrics.controlCornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.craneInk.opacity(0.06))
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                }
        }
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

    /// Menu-bar dashboard shell background.
    func craneDashboardBackground() -> some View {
        background {
            Color.craneSurface.opacity(0.02)
                .background(.regularMaterial)
        }
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
                    .fill(CraneColor.accentSoft(for: colorScheme))
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.regularMaterial)
                    }
            } else if isHighlighted {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.craneInk.opacity(0.06))
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.regularMaterial)
                    }
            }
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
                .strokeBorder(CraneColor.accentLine(for: colorScheme), lineWidth: isFocused ? 0.5 : 0)
                .animation(.craneSnappy, value: isFocused)
                .allowsHitTesting(false)
        }
    }
}
