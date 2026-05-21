//
//  CraneButtonStyles.swift
//  crane
//

import SwiftUI

struct CranePrimaryButtonStyle: ButtonStyle {
    var isHovered: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let fill = CraneColor.accentFill(for: colorScheme)
        let pressed = configuration.isPressed
        return configuration.label
            .font(CraneFont.ui(13, weight: .medium))
            .foregroundStyle(CraneColor.cream)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                fill.opacity(isEnabled ? (pressed ? 0.85 : (isHovered ? 1 : 0.95)) : 0.45),
                in: RoundedRectangle(cornerRadius: DesignMetrics.chipCornerRadius, style: .continuous)
            )
            .shadow(
                color: isEnabled ? CraneColor.accentGlow(for: colorScheme) : .clear,
                radius: pressed ? 4 : (isHovered ? 10 : 8),
                y: 2
            )
            .animation(.craneSnappy, value: pressed)
            .animation(.craneSnappy, value: isHovered)
    }
}

struct CraneSecondaryButtonStyle: ButtonStyle {
    var isHovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(CraneFont.ui(13, weight: .medium))
            .foregroundStyle(pressed ? Color.craneInk : (isHovered ? Color.craneInk : Color.craneInkSecondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if isHovered || pressed {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .fill(Color.craneInk.opacity(pressed ? 0.08 : 0.06))
                }
            }
            .animation(.craneSnappy, value: pressed)
            .animation(.craneSnappy, value: isHovered)
    }
}

struct CraneTertiaryButtonStyle: ButtonStyle {
    var isHovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(CraneFont.ui(13, weight: .medium))
            .foregroundStyle(pressed ? Color.craneInkSecondary : (isHovered ? Color.craneInkSecondary : Color.craneInkTertiary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if isHovered || pressed {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .fill(Color.craneInk.opacity(0.05))
                }
            }
            .animation(.craneSnappy, value: pressed)
            .animation(.craneSnappy, value: isHovered)
    }
}

/// Primary button with hover tracking for menu-bar / dashboard CTAs.
struct CranePrimaryButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(CranePrimaryButtonStyle(isHovered: hovering))
            .onHover { hovering = $0 }
    }
}

/// Secondary text button with hover recess for section actions and inline confirms.
struct CraneSecondaryButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(CraneSecondaryButtonStyle(isHovered: hovering))
            .onHover { hovering = $0 }
    }
}

/// Tertiary text button for low-priority actions (Quit, dismiss).
struct CraneTertiaryButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(CraneTertiaryButtonStyle(isHovered: hovering))
            .onHover { hovering = $0 }
    }
}

extension ButtonStyle where Self == CranePrimaryButtonStyle {
    static var cranePrimary: CranePrimaryButtonStyle { CranePrimaryButtonStyle() }
}

extension ButtonStyle where Self == CraneSecondaryButtonStyle {
    static var craneSecondary: CraneSecondaryButtonStyle { CraneSecondaryButtonStyle() }
}

extension ButtonStyle where Self == CraneTertiaryButtonStyle {
    static var craneTertiary: CraneTertiaryButtonStyle { CraneTertiaryButtonStyle() }
}
