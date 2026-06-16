//
//  OverlayController.swift
//  crane
//
//  Owns the floating panel and the SwiftUI hierarchy hosted inside it.
//  Replaces the Rust `toggle_window` and view-state management that
//  the Tauri version handled by emitting "reset-to-input".
//

import AppKit
import SwiftUI
import SwiftData
import Observation

/// What's currently shown in the overlay panel.
enum OverlayView: Equatable {
    case input
    case history
}

@Observable
@MainActor
final class OverlayController {

    /// Logical sizes. The panel is the glass surface plus a transparent shadow
    /// margin on every side, so the Liquid Glass drop shadow follows the rounded
    /// shape instead of being clipped into a rectangle.
    private static let shadowMargin = DesignMetrics.overlayShadowMargin
    static let inputSize = NSSize(
        width: DesignMetrics.overlayGlassWidth + shadowMargin * 2,
        height: DesignMetrics.captureGlassHeight + shadowMargin * 2
    )
    static let historySize = NSSize(
        width: DesignMetrics.overlayGlassWidth + shadowMargin * 2,
        height: DesignMetrics.historyGlassHeight + shadowMargin * 2
    )

    /// Currently displayed view. Mutating this animates the panel resize.
    var currentView: OverlayView = .input {
        didSet { applySize(for: currentView, animated: true) }
    }

    /// When set, `HistoryView` scrolls to this drop after appearing.
    var scrollToDropID: UUID?

    /// Bumped whenever scroll should run (including repeated focus on the same drop).
    private(set) var scrollToken = UUID()

    /// Bumped on every dismiss so `DropInputBar` clears draft state even
    /// when Esc is handled at the panel level instead of SwiftUI.
    private(set) var inputResetToken = UUID()

    /// When set, `HistoryView` pre-fills the search field (e.g. from a tag chip).
    var historySearchQuery: String?

    /// Frontmost app name captured before the overlay takes key focus.
    private(set) var capturedSourceApp: String?

    /// Invalidates in-flight post-save dismiss callbacks.
    private var saveDismissGeneration = 0

    private var scrollHighlightClearTask: Task<Void, Never>?

    private static let screenMargin: CGFloat = 16

    private let panel: OverlayPanel
    private var hostingView: NSHostingView<AnyView>?
    private var glassView: NSGlassEffectView?
    private var screenObserver: NSObjectProtocol?

    init() {
        panel = OverlayPanel(initialSize: Self.inputSize)
        panel.onCancel = { [weak self] in self?.handleCancelKey() }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            self.positionOnActiveScreen()
        }
    }

    /// Install the SwiftUI root once the controller is wired up — we pass
    /// `self` as an environment object so views can resize / dismiss, and
    /// attach the shared SwiftData `ModelContainer` so the input bar and
    /// history list see the same drops the menu-bar dashboard does.
    func attach(rootView: some View) {
        let wrapped = AnyView(
            rootView
                .environment(self)
                .modelContainer(Persistence.container)
        )
        let host = NSHostingView(rootView: wrapped)
        let container = CraneGlassHost.wrap(
            contentView: host,
            containerSize: panel.frame.size,
            margin: DesignMetrics.glassShadowMargin
        )
        panel.contentView = container
        hostingView = host
        glassView = container.subviews.first as? NSGlassEffectView
    }

    // MARK: - Show / Hide / Toggle

    func show() {
        cancelAfterSaveDismiss()
        cancelScrollHighlightClearTask()
        captureSourceApp()
        // Always start in the input view (matches Tauri "reset-to-input").
        if currentView != .input {
            currentView = .input
        }
        // Clear post-save checkmark / disabled state when reopening without hide.
        inputResetToken = UUID()
        scrollToDropID = nil
        historySearchQuery = nil
        positionOnActiveScreen()
        // Activate so the field editor shows a blinking insertion point in this
        // key-only accessory panel (nonactivating panels won't animate the caret
        // while another app is still "active").
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeMain()
    }

    /// Show the history list, optionally scrolling to a specific drop.
    func openHistory(focusing dropID: UUID? = nil, search: String? = nil) {
        cancelAfterSaveDismiss()
        cancelScrollHighlightClearTask()
        captureSourceApp()
        scrollToDropID = dropID
        scrollToken = UUID()
        historySearchQuery = search?.trimmingCharacters(in: .whitespacesAndNewlines)
        if historySearchQuery?.isEmpty == true { historySearchQuery = nil }
        if currentView != .history {
            currentView = .history
        }
        positionOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeMain()
    }

    func hide() {
        cancelAfterSaveDismiss()
        clearScrollHighlight()
        historySearchQuery = nil
        capturedSourceApp = nil
        inputResetToken = UUID()
        panel.orderOut(nil)
    }

    /// Schedules `block` after a save animation unless superseded by show/hide.
    func scheduleAfterSaveDismiss(after seconds: TimeInterval = 0.45, _ block: @escaping () -> Void) {
        saveDismissGeneration += 1
        let generation = saveDismissGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard generation == self.saveDismissGeneration else { return }
            block()
        }
    }

    func cancelAfterSaveDismiss() {
        saveDismissGeneration += 1
    }

    /// Clears the scroll-to highlight after the user has seen the focused row.
    func scheduleScrollHighlightClear(after seconds: TimeInterval = 2.5) {
        scrollHighlightClearTask?.cancel()
        scrollHighlightClearTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            clearScrollHighlight()
        }
    }

    func clearScrollHighlight() {
        cancelScrollHighlightClearTask()
        scrollToDropID = nil
    }

    private func cancelScrollHighlightClearTask() {
        scrollHighlightClearTask?.cancel()
        scrollHighlightClearTask = nil
    }

    /// Esc: history → input pill; input → dismiss overlay.
    private func handleCancelKey() {
        if currentView == .history {
            currentView = .input
        } else {
            hide()
        }
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    var isVisible: Bool { panel.isVisible }

    /// Automated checks for the AppKit glass host (see `scripts/test-overlay-glass.sh`).
    @MainActor
    func verifyGlassSetupForTesting() -> OverlayGlassVerifier.Result {
        OverlayGlassVerifier.verify(panel: panel, view: currentView)
    }

    // MARK: - Layout

    /// Place the panel horizontally centered, vertically in the upper third
    /// (the Spotlight / Raycast resting position).
    private func positionOnActiveScreen() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? panel.screen
        guard let visible = screen?.visibleFrame else { return }

        var frame = panel.frame
        frame = clampFrame(frame, to: visible)
        let x = visible.origin.x + (visible.width - frame.width) / 2
        let y = visible.origin.y + visible.height - frame.height - (visible.height * 0.28)
        frame.origin = NSPoint(x: x.rounded(), y: y.rounded())
        panel.setFrame(clampFrame(frame, to: visible), display: true)
    }

    private func applySize(for view: OverlayView, animated: Bool) {
        let target = view == .input ? Self.inputSize : Self.historySize
        let current = panel.frame
        let visible = panel.screen?.visibleFrame
            ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        // Anchor to the top edge so the bar stays put while the panel grows
        // downward into the history list.
        var newOrigin = NSPoint(
            x: current.origin.x + (current.width - target.width) / 2,
            y: current.origin.y + (current.height - target.height)
        )
        var newFrame = NSRect(origin: newOrigin, size: target)
        if let visible {
            newFrame = clampFrame(newFrame, to: visible)
        }
        panel.setFrame(newFrame, display: true, animate: animated)
    }

    /// Keeps the panel fully inside the active display's visible area.
    private func clampFrame(_ frame: NSRect, to visible: NSRect) -> NSRect {
        let margin = Self.screenMargin
        var f = frame
        let maxW = max(200, visible.width - margin * 2)
        let maxH = max(Self.inputSize.height, visible.height - margin * 2)
        f.size.width = min(f.width, maxW)
        f.size.height = min(f.height, maxH)
        f.origin.x = min(
            max(f.origin.x, visible.minX + margin),
            visible.maxX - f.width - margin
        )
        f.origin.y = min(
            max(f.origin.y, visible.minY + margin),
            visible.maxY - f.height - margin
        )
        return f
    }

    private func captureSourceApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            capturedSourceApp = nil
            return
        }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            capturedSourceApp = nil
            return
        }
        capturedSourceApp = app.localizedName
    }
}
