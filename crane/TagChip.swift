//
//  TagChip.swift
//  crane
//
//  Small pill for FM-extracted tags on the dashboard and in history rows.
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

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    chipLabel
                }
                .buttonStyle(.plain)
            } else {
                chipLabel
            }
        }
    }

    private var chipLabel: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(style == .dashboard ? Color.accentColor : .secondary)
            .padding(.horizontal, style == .dashboard ? 8 : 6)
            .padding(.vertical, style == .dashboard ? 4 : 2)
            .background(
                (style == .dashboard
                    ? Color.accentColor.opacity(0.12)
                    : Color.primary.opacity(0.06)),
                in: Capsule(style: .continuous)
            )
            .lineLimit(1)
    }
}
