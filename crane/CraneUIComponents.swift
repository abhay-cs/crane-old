//
//  CraneUIComponents.swift
//  crane
//
//  Shared interactive primitives: icon buttons, motion helpers.
//

import SwiftUI

// MARK: - Motion

enum CraneMotion {
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : animation
    }
}

// MARK: - Icon button

struct CraneIconButton: View {
    let systemName: String
    var iconSize: CGFloat = 12
    var usesRecess: Bool = false
    var help: String? = nil
    var accessibilityLabel: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(hovering ? Color.craneInkSecondary : Color.craneInkTertiary)
                .frame(width: 28, height: 28)
                .background {
                    if usesRecess {
                        RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                            .fill(Color.craneInk.opacity(0.06))
                            .background {
                                RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                                    .fill(.regularMaterial)
                            }
                    } else if hovering {
                        RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                            .fill(Color.craneInk.opacity(0.06))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.craneSnappy, value: hovering)
        .optionalHelp(help)
        .optionalAccessibilityLabel(accessibilityLabel)
    }
}

private extension View {
    @ViewBuilder
    func optionalHelp(_ help: String?) -> some View {
        if let help {
            self.help(help)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalAccessibilityLabel(_ label: String?) -> some View {
        if let label {
            self.accessibilityLabel(label)
        } else {
            self
        }
    }
}
