//
//  EmptyStateView.swift
//  crane
//

import SwiftUI

struct EmptyStateView: View {
    var symbol: String = "tray"
    let message: String
    var primaryTitle: String = "Capture drop"
    var primaryAction: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.craneInkTertiary)
                .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(CraneFont.ui(13))
                .foregroundStyle(Color.craneInkTertiary)
                .multilineTextAlignment(.center)

            if let primaryAction {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.cranePrimary)
            }

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.craneSecondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}
