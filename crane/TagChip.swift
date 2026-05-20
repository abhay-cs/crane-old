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

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chipLabel }
                    .buttonStyle(.plain)
            } else {
                chipLabel
            }
        }
    }

    private var chipLabel: some View {
        Text(label)
            .font(CraneFont.ui(11, weight: .medium))
            .foregroundStyle(style == .dashboard ? CraneColor.accent : Color.craneInkSecondary)
            .padding(.horizontal, style == .dashboard ? 8 : 6)
            .padding(.vertical, style == .dashboard ? 4 : 2)
            .background(
                style == .dashboard
                    ? AnyShapeStyle(Color.craneCream.opacity(0.14))
                    : AnyShapeStyle(Color.craneInk.opacity(0.06)),
                in: Capsule(style: .continuous)
            )
            .lineLimit(1)
    }
}
