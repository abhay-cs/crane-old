//
//  EmptyStateView.swift
//  crane
//
//  Shared empty-state pattern: short message plus a primary action.
//

import SwiftUI

struct EmptyStateView: View {
    let message: String
    var primaryTitle: String = "Capture drop"
    var primaryAction: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if let primaryAction {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}
