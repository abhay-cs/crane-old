//
//  EmptyStateView.swift
//  crane
//

import SwiftUI

struct EmptyStateView: View {
    var symbol: String = "tray"
    var headline: String? = nil
    let message: String
    var primaryTitle: String = "Capture drop"
    var primaryAction: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(CraneColor.accentSoft(for: colorScheme))
                    .frame(width: 52, height: 52)
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 6) {
                if let headline {
                    Text(headline)
                        .font(CraneFont.display(18))
                        .tracking(-0.15)
                        .foregroundStyle(Color.craneInk)
                        .multilineTextAlignment(.center)
                }

                Text(message)
                    .font(CraneFont.ui(14))
                    .foregroundStyle(Color.craneInkTertiary)
                    .multilineTextAlignment(.center)
            }

            if let primaryAction {
                CranePrimaryButton(action: primaryAction) {
                    Text(primaryTitle)
                }
            }

            if let secondaryTitle, let secondaryAction {
                CraneSecondaryButton(action: secondaryAction) {
                    Text(secondaryTitle)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}
