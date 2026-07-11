//
//  OnboardingController.swift
//  crane
//
//  First-run guided tour (issues.md P2-21). Owns a small non-activating
//  floating "coach card" panel at the bottom of the screen that teaches the
//  core loop by having the user actually do it: press ⌘⇧Space, save a drop,
//  find it in the menu bar. Steps advance from app events rather than
//  Next buttons; completion persists in `UserDefaults` so the tour shows
//  once, with a menu-bar replay (Capture → Welcome Tour…).
//

import AppKit
import SwiftUI
import Observation

// MARK: - Tour progress events

extension Notification.Name {
    /// Posted by `OverlayController.show()` when the capture pill appears.
    static let craneOverlayDidShow = Notification.Name("craneOverlayDidShow")
    /// Posted by `OverlayController.hide()` when the overlay dismisses.
    static let craneOverlayDidHide = Notification.Name("craneOverlayDidHide")
    /// Posted by the capture bar after a drop saves successfully.
    static let craneDropDidSave = Notification.Name("craneDropDidSave")
}

/// One step of the tour, in the order the user performs them.
enum OnboardingStep: Int, CaseIterable {
    /// Press ⌘⇧Space (or click the fallback button) to open the capture bar.
    case capture
    /// Type a thought and press Enter.
    case save
    /// Find the saved drop behind the menu-bar icon.
    case review
}

@Observable
@MainActor
final class OnboardingController {

    static let completedDefaultsKey = "craneHasCompletedOnboarding"

    /// Visible glass card. The hosting panel adds the transparent shadow
    /// margin on every side, same as the overlay.
    static let cardSize = NSSize(width: 460, height: 176)
    private static let shadowMargin = DesignMetrics.glassShadowMargin
    static let panelSize = NSSize(
        width: cardSize.width + shadowMargin * 2,
        height: cardSize.height + shadowMargin * 2
    )
    /// Gap between the card and the bottom of the visible screen area.
    private static let bottomInset: CGFloat = 48

    private(set) var step: OnboardingStep = .capture

    private var panel: NSPanel?
    private var observers: [NSObjectProtocol] = []

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedDefaultsKey)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Automated checks only (see `OnboardingVerifier`).
    var panelForTesting: NSPanel? { panel }

    // MARK: - Show / complete

    /// First-launch entry point; no-op once the tour was finished or skipped.
    func showIfNeeded() {
        guard !Self.hasCompleted else { return }
        show()
    }

    /// Starts (or restarts) the tour from step one.
    func show() {
        step = .capture
        let panel = self.panel ?? makePanel()
        self.panel = panel
        startObserving()
        position(panel)
        panel.orderFrontRegardless()
    }

    /// "Done" on the last step.
    func finish() { complete() }

    /// "Skip tour" on any step.
    func skip() { complete() }

    private func complete() {
        UserDefaults.standard.set(true, forKey: Self.completedDefaultsKey)
        stopObserving()
        panel?.orderOut(nil)
    }

    // MARK: - Step progression (driven by real app events)

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: .craneOverlayDidShow, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, self.step == .capture else { return }
                self.step = .save
            }
        })

        // Dismissing the capture bar without saving rewinds to step one so
        // the card never instructs "press Enter" while nothing is open.
        observers.append(center.addObserver(
            forName: .craneOverlayDidHide, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, self.step == .save else { return }
                self.step = .capture
            }
        })

        observers.append(center.addObserver(
            forName: .craneDropDidSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                self.step = .review
            }
        })

        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, panel.isVisible else { return }
                self.position(panel)
            }
        })
    }

    private func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    // MARK: - Panel

    private func makePanel() -> NSPanel {
        let panel = OnboardingPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        // Fix the SwiftUI ideal size: the hosting view's Auto Layout constraints
        // drive the panel frame, and a fully flexible root balloons the window.
        let host = NSHostingView(rootView: AnyView(
            OnboardingView()
                .environment(self)
                .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        ))
        let container = CraneGlassHost.wrap(
            contentView: host,
            containerSize: Self.panelSize,
            margin: Self.shadowMargin
        )
        panel.contentView = container
        return panel
    }

    /// Bottom-center of the screen the cursor is on, clear of the capture
    /// pill and history card that live in the upper third.
    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? panel.screen
        guard let visible = screen?.visibleFrame else { return }

        var frame = panel.frame
        frame.origin = NSPoint(
            x: (visible.origin.x + (visible.width - frame.width) / 2).rounded(),
            y: (visible.origin.y + Self.bottomInset - Self.shadowMargin).rounded()
        )
        panel.setFrame(frame, display: true)
    }
}

/// Borderless panels refuse key status by default; the card needs it so its
/// buttons take clicks. `.nonactivatingPanel` keeps crane from stealing app
/// focus when that happens.
private final class OnboardingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
