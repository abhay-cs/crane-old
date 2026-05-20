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

    /// Logical sizes. Input panel hugs the 64pt capture pill with 12pt of
    /// transparent padding on each side; history keeps the original 480pt
    /// height so the list has room to scroll.
    /// Two-row capture pill: input row + hint row + padding.
    static let inputSize  = NSSize(width: 620, height: 116)
    static let historySize = NSSize(width: 620, height: 480)

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

    private static let screenMargin: CGFloat = 16

    private let panel: OverlayPanel
    private var hostingView: NSHostingView<AnyView>?
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
        host.frame = NSRect(origin: .zero, size: panel.frame.size)
        host.autoresizingMask = [.width, .height]
        // macOS 26 gives NSHostingView a translucent material backing by
        // default, which shows up as a faint rounded rectangle behind the
        // input pill (visible in the 12pt padding around the bar and the
        // ~20pt of empty panel space below it). Force the backing layer
        // fully clear so only the pill's own `.glassEffect` is visible.
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.isOpaque = false
        panel.contentView = host
        hostingView = host
    }

    // MARK: - Show / Hide / Toggle

    func show() {
        cancelAfterSaveDismiss()
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
        scrollToDropID = nil
        historySearchQuery = nil
        capturedSourceApp = nil
        inputResetToken = UUID()
        panel.orderOut(nil)
    }

    /// Schedules `block` after a save animation unless superseded by show/hide.
    func scheduleAfterSaveDismiss(_ block: @escaping () -> Void) {
        saveDismissGeneration += 1
        let generation = saveDismissGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard generation == self.saveDismissGeneration else { return }
            block()
        }
    }

    func cancelAfterSaveDismiss() {
        saveDismissGeneration += 1
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
