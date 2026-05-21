//
//  CraneSectionHeader.swift
//  crane
//

import SwiftUI

struct CraneSectionHeader: View {
    enum CapsEmphasis {
        /// Primary section — accent mono caps (use sparingly).
        case accent
        /// Secondary sections — neutral caps to preserve one accent moment per surface.
        case neutral
    }

    var caps: String? = nil
    var capsEmphasis: CapsEmphasis = .neutral
    var title: String? = nil
    var trailing: String?
    var trailingActionTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            headerLabel
            Spacer(minLength: 8)
            trailingContent
        }
    }

    @ViewBuilder
    private var headerLabel: some View {
        if let caps {
            Text(caps)
                .font(CraneFont.mono(12, weight: .medium))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(capsForeground)
        } else if let title {
            Text(title)
                .font(CraneFont.ui(13, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.craneInk)
        }
    }

    private var capsForeground: Color {
        switch capsEmphasis {
        case .accent: CraneColor.accent
        case .neutral: Color.craneInkTertiary
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if let trailing {
            Text(trailing)
                .font(CraneFont.ui(12, weight: .medium))
                .foregroundStyle(.craneInkTertiary)
        } else if let trailingActionTitle, let trailingAction {
            CraneSecondaryButton(action: trailingAction) {
                Text(trailingActionTitle)
            }
        }
    }
}

struct CraneDashboardDivider: View {
    var body: some View {
        Rectangle()
            .fill(CraneColor.creamLine)
            .frame(height: 0.5)
            .padding(.vertical, 4)
    }
}
