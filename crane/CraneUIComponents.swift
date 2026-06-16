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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(CraneFont.symbol(iconSize, weight: .medium))
                .foregroundStyle(hovering ? Color.craneInkSecondary : Color.craneInkTertiary)
                .frame(width: 28, height: 28)
                .background {
                    if usesRecess {
                        RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                            .fill(CraneColor.recessFill(for: colorScheme))
                    } else if hovering {
                        RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                            .fill(CraneColor.recessFill(for: colorScheme))
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

// MARK: - Mirror text field

/// Invisible `TextField` captures keys; a SwiftUI `Text` overlay paints glyphs and
/// aligns with the AppKit caret in transparent overlay panels.
struct CraneMirrorTextField: View {
    @Binding var text: String
    var placeholder: String
    var font: Font
    var tracking: CGFloat = 0
    var height: CGFloat? = nil
    /// Fine-tunes overlay text to the AppKit caret (positive moves down).
    var verticalNudge: CGFloat = 0
    var focusedLeadingPadding: CGFloat = 3
    var isEnabled: Bool = true
    var accessibilityLabel: String? = nil
    var accessibilityHint: String? = nil
    @FocusState.Binding var isFocused: Bool
    var onSubmit: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let caretColor = CraneColor.caret(for: colorScheme)
        ZStack(alignment: .leading) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(Color.clear)
                .tint(caretColor)
                .focused($isFocused)
                .disabled(!isEnabled)
                .disableAutocorrection(true)
                .onSubmit { onSubmit?() }
                .optionalAccessibilityLabel(accessibilityLabel)
                .optionalAccessibilityHint(accessibilityHint)

            if text.isEmpty, !isFocused {
                Text(placeholder)
                    .font(font)
                    .tracking(tracking)
                    .foregroundStyle(Color.craneInkTertiary)
                    .padding(.leading, isFocused ? focusedLeadingPadding : 0)
                    .offset(y: verticalNudge)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            } else if !text.isEmpty {
                Text(text)
                    .font(font)
                    .tracking(tracking)
                    .foregroundStyle(Color.craneInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .offset(y: verticalNudge)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
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

    @ViewBuilder
    func optionalAccessibilityHint(_ hint: String?) -> some View {
        if let hint {
            self.accessibilityHint(hint)
        } else {
            self
        }
    }
}
