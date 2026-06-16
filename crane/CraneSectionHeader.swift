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

    enum LabelStyle {
        /// Legacy ALL CAPS mono labels (history overlay, etc.).
        case caps(CapsEmphasis)
        /// Journal section titles — Instrument Serif, sentence case.
        case journal
        /// Utility section titles — Geist semibold.
        case utility
    }

    var label: String
    var labelStyle: LabelStyle = .utility
    var trailing: String?
    var trailingActionTitle: String?
    var trailingAction: (() -> Void)?

    /// Caps-style header (overlay / legacy surfaces).
    init(
        caps: String,
        capsEmphasis: CapsEmphasis = .neutral,
        trailing: String? = nil,
        trailingActionTitle: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        label = caps
        labelStyle = .caps(capsEmphasis)
        self.trailing = trailing
        self.trailingActionTitle = trailingActionTitle
        self.trailingAction = trailingAction
    }

    /// Journal or utility title header.
    init(
        title: String,
        style: LabelStyle = .utility,
        trailing: String? = nil,
        trailingActionTitle: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        label = title
        labelStyle = style
        self.trailing = trailing
        self.trailingActionTitle = trailingActionTitle
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            headerLabel
            Spacer(minLength: 8)
            trailingContent
        }
    }

    @ViewBuilder
    private var headerLabel: some View {
        switch labelStyle {
        case .caps(let emphasis):
            Text(label)
                .font(CraneFont.mono(12, weight: .medium))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(capsForeground(for: emphasis))
        case .journal:
            Text(label)
                .craneText(.journalSection)
        case .utility:
            Text(label)
                .craneText(.section)
        }
    }

    private func capsForeground(for emphasis: CapsEmphasis) -> Color {
        switch emphasis {
        case .accent: CraneColor.sage
        case .neutral: Color.craneInkTertiary
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if let trailing {
            Text(trailing)
                .craneText(.meta)
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
