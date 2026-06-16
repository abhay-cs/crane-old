//
//  OverlayGlassVerifier.swift
//  crane
//
//  Automated checks for AppKit NSGlassEffectView hosts (overlay + dashboard).
//

import AppKit

enum OverlayGlassVerifier {

    struct Result: Encodable {
        let passed: Bool
        let failures: [String]
        let panelSize: CGSize
        let glassFrame: CGRect
        let glassCornerRadius: CGFloat
        let view: String
    }

    @MainActor
    static func verify(panel: OverlayPanel, view: OverlayView) -> Result {
        let expectedSize = view == .input ? OverlayController.inputSize : OverlayController.historySize
        return verify(
            window: panel,
            expectedContainerSize: expectedSize,
            margin: DesignMetrics.glassShadowMargin,
            label: String(describing: view)
        )
    }

    @MainActor
    static func verify(
        window: NSWindow,
        expectedContainerSize: NSSize,
        margin: CGFloat,
        label: String
    ) -> Result {
        var failures: [String] = []

        if window.hasShadow {
            failures.append("window.hasShadow should be false")
        }
        if window.backgroundColor != .clear {
            failures.append("window.backgroundColor should be clear")
        }

        guard let container = window.contentView else {
            failures.append("window.contentView is nil")
            return failureResult(
                failures: failures,
                window: window,
                label: label
            )
        }

        container.wantsLayer = true
        if container.layer?.backgroundColor != NSColor.clear.cgColor {
            failures.append("container layer background should be clear")
        }

        guard container.subviews.count == 1,
              let glass = container.subviews.first as? NSGlassEffectView else {
            failures.append("expected exactly one NSGlassEffectView subview, found \(container.subviews.count)")
            return failureResult(
                failures: failures,
                window: window,
                label: label
            )
        }

        if glass.style != .regular {
            failures.append("glass.style should be .regular")
        }
        if glass.cornerRadius != DesignMetrics.surfaceCornerRadius {
            failures.append("glass.cornerRadius should be \(DesignMetrics.surfaceCornerRadius)")
        }
        if !glass.clipsToBounds {
            failures.append("glass.clipsToBounds should be true")
        }
        if glass.contentView == nil {
            failures.append("glass.contentView should host SwiftUI content")
        }

        let expectedGlass = container.bounds.insetBy(dx: margin, dy: margin)
        if abs(glass.frame.origin.x - expectedGlass.origin.x) > 0.5
            || abs(glass.frame.origin.y - expectedGlass.origin.y) > 0.5
            || abs(glass.frame.width - expectedGlass.width) > 0.5
            || abs(glass.frame.height - expectedGlass.height) > 0.5 {
            failures.append(
                "glass.frame \(glass.frame) should match inset bounds \(expectedGlass)"
            )
        }

        if abs(window.frame.width - expectedContainerSize.width) > 0.5
            || abs(window.frame.height - expectedContainerSize.height) > 0.5 {
            failures.append(
                "window size \(window.frame.size) should match \(expectedContainerSize)"
            )
        }

        if let host = glass.contentView {
            host.wantsLayer = true
            if (host.layer?.shadowOpacity ?? 0) > 0 {
                failures.append("hosting view layer shadowOpacity should be 0")
            }
        }

        return Result(
            passed: failures.isEmpty,
            failures: failures,
            panelSize: window.frame.size,
            glassFrame: glass.frame,
            glassCornerRadius: glass.cornerRadius,
            view: label
        )
    }

    private static func failureResult(
        failures: [String],
        window: NSWindow,
        label: String
    ) -> Result {
        Result(
            passed: false,
            failures: failures,
            panelSize: window.frame.size,
            glassFrame: .zero,
            glassCornerRadius: 0,
            view: label
        )
    }
}
