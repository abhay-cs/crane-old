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
    private var wakeObserver: NSObjectProtocol?

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        if SingleInstance.shouldTerminateAsDuplicate() {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        NSApp.setActivationPolicy(.accessory)

        overlay.attach(rootView: ContentView())

        let hotkeyOK = registerHotkey()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerHotkey()
        }

        CraneAlert.presentLaunchWarnings(
            hotkeyFailed: !hotkeyOK,
            ephemeralStore: Persistence.isEphemeralStore
        )

        Task {
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run {
                AIJobQueue.shared.backfillUntaggedDrops(limit: 10)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        hotkey.unregister()
        SingleInstance.releaseLock()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Hotkey

    @discardableResult
    private func registerHotkey() -> Bool {
        hotkey.registerCommandShiftSpace { [weak self] in
            self?.toggleOverlay()
        }
    }

    // MARK: - Public API (called from MenuBarExtra)

    func toggleOverlay() {
        overlay.toggle()
    }

    func showOverlay() {
        overlay.show()
    }

    func showOverlayHistory(focusing dropID: UUID? = nil, search: String? = nil) {
        overlay.openHistory(focusing: dropID, search: search)
    }
}
