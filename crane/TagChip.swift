//
//  TagChip.swift
//  crane
//

import SwiftUI

struct TagChip: View {
    enum Style {
        case dashboard
        case compact
    }

    let label: String
    var style: Style = .dashboard
    var action: (() -> Void)?

    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var isInteractive: Bool { action != nil && style == .dashboard }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chipLabel }
                    .buttonStyle(.plain)
                    .onHover { hovering = $0 }
            } else {
                chipLabel
            }
        }
        .animation(.craneSnappy, value: hovering)
    }

    private var chipLabel: some View {
        Text(label)
            .font(chipFont)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, style == .dashboard ? 8 : 6)
            .padding(.vertical, style == .dashboard ? 4 : 2)
            .background(backgroundFill, in: Capsule(style: .continuous))
            .overlay {
                if isInteractive && hovering {
                    Capsule(style: .continuous)
                        .strokeBorder(CraneColor.sageLine(for: colorScheme), lineWidth: 0.5)
                }
            }
            .lineLimit(1)
    }

    private var chipFont: Font {
        switch style {
        case .dashboard: CraneFont.ui(13, weight: .medium)
        case .compact: CraneFont.ui(11, weight: .medium)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .compact:
            return Color.craneInkSecondary
        case .dashboard:
            return isInteractive && hovering ? Color.craneInk : Color.craneInkSecondary
        }
    }

    private var backgroundFill: AnyShapeStyle {
        switch style {
        case .compact:
            return AnyShapeStyle(CraneColor.recessFill(for: colorScheme))
        case .dashboard:
            if isInteractive && hovering {
                return AnyShapeStyle(CraneColor.sage.opacity(colorScheme == .dark ? 0.22 : 0.16))
            }
            return AnyShapeStyle(CraneColor.sageSoft(for: colorScheme))
        }
    }
}
