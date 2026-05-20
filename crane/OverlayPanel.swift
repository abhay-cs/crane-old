//
//  OverlayPanel.swift
//  crane
//
//  Borderless, transparent, floating NSPanel that hosts the SwiftUI overlay.
//

import AppKit
import SwiftUI

/// Spotlight-style panel: borderless, no chrome, can take key input,
/// floats above other windows, joins all spaces.
final class OverlayPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    /// Lets the field editor install with a blinking insertion point.
    override var canBecomeMain: Bool { true }

    init(initialSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .fullSizeContentView],
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
        becomesKeyOnlyIfNeeded = false
        invalidateShadow()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    var onCancel: (() -> Void)?
}
