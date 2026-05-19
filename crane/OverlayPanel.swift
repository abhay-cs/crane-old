//
//  OverlayPanel.swift
//  crane
//
//  Borderless, transparent, floating NSPanel that hosts the SwiftUI overlay.
//  Replaces the Tauri "main" window (transparent, decorations: false,
//  alwaysOnTop: true, shadow: false, skipTaskbar: true).
//

import AppKit
import SwiftUI

/// Spotlight-style panel: borderless, no chrome, can take key input,
/// floats above other windows, joins all spaces.
final class OverlayPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(initialSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        hidesOnDeactivate = false
        worksWhenModal = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        // Avoid the brief opaque flash when first ordering in.
        invalidateShadow()
    }

    /// Esc must close even when a TextField inside has focus and there's no
    /// `.cancelAction` button to consume it — fall through to the action set
    /// by the controller.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Closure invoked when the user hits Escape at the panel level.
    var onCancel: (() -> Void)?
}
