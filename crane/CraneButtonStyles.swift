//
//  CraneButtonStyles.swift
//  crane
//

import SwiftUI

struct CranePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let fill = CraneColor.accentFill(for: colorScheme)
        return configuration.label
            .font(CraneFont.ui(12, weight: .medium))
            .foregroundStyle(CraneColor.cream)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                fill.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45),
                in: RoundedRectangle(cornerRadius: DesignMetrics.chipCornerRadius, style: .continuous)
            )
            .animation(.craneSnappy, value: configuration.isPressed)
    }
}

struct CraneSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CraneFont.ui(12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? Color.craneInk : Color.craneInkSecondary)
            .animation(.craneSnappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CranePrimaryButtonStyle {
    static var cranePrimary: CranePrimaryButtonStyle { CranePrimaryButtonStyle() }
}

extension ButtonStyle where Self == CraneSecondaryButtonStyle {
    static var craneSecondary: CraneSecondaryButtonStyle { CraneSecondaryButtonStyle() }
}
