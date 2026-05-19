//
//  AppDelegate.swift
//  crane
//
//  Bridges SwiftUI `@main` with the AppKit pieces that have no SwiftUI
//  equivalent: hiding from Dock / Cmd-Tab, registering a global hotkey,
//  and owning the floating overlay panel.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) weak var shared: AppDelegate?

    private(set) lazy var overlay: OverlayController = OverlayController()
    private let hotkey = GlobalHotkey()

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        if SingleInstance.shouldTerminateAsDuplicate() {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Run as a menu-bar / accessory app: no Dock icon, no Cmd-Tab entry.
        // Mirrors `set_activation_policy(ActivationPolicy::Accessory)` in Rust.
        NSApp.setActivationPolicy(.accessory)

        // Build SwiftUI hierarchy and install it in the panel.
        overlay.attach(rootView: ContentView())

        // Register the global hotkey: ⌘⇧Space → toggle the overlay.
        let hotkeyOK = hotkey.registerCommandShiftSpace { [weak self] in
            self?.toggleOverlay()
        }
        if !hotkeyOK {
            CraneAlert.presentHotkeyRegistrationFailed()
        }

        if Persistence.isEphemeralStore {
            CraneAlert.presentEphemeralStore()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.unregister()
    }

    /// Don't quit when the (non-existent) main window closes — we're a
    /// menu-bar app and the user quits via the tray menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Public API (called from MenuBarExtra)

    func toggleOverlay() {
        overlay.toggle()
    }

    func showOverlay() {
        overlay.show()
    }

    func showOverlayHistory(focusing dropID: UUID? = nil) {
        overlay.openHistory(focusing: dropID)
    }
}
