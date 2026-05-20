//
//  CraneAlert.swift
//  crane
//
//  AppKit alerts for errors that SwiftUI surfaces cannot easily show from
//  a borderless overlay (save failures, persistence, hotkey registration).
//

import AppKit

enum CraneAlert {

    /// One modal at launch for hotkey + persistence issues (avoids stacked dialogs).
    @MainActor
    static func presentLaunchWarnings(hotkeyFailed: Bool, ephemeralStore: Bool) {
        guard hotkeyFailed || ephemeralStore else { return }

        let alert = NSAlert()
        var lines: [String] = []

        if ephemeralStore {
            alert.messageText = "crane can’t access its database"
            alert.alertStyle = .critical
            var body =
                "Your drops will only be kept until you quit. "
                + "Quit other copies of crane, then restart."
            if let archive = Persistence.lastArchivedStorePath {
                body += "\n\nA backup of the broken store was saved to:\n\(archive)"
            }
            body +=
                "\n\nStore directory:\n\(Persistence.storeDirectoryPath)"
                + "\n\nIf drops.json is still there, crane will merge it on the next successful launch."
            lines.append(body)
        } else if hotkeyFailed {
            alert.messageText = "Global shortcut unavailable"
            alert.alertStyle = .warning
        }

        if hotkeyFailed {
            lines.append(
                "crane couldn’t register ⌘⇧Space. Another app may be using that combo. "
                + "Open the menu-bar window and choose New Drop, or quit the conflicting app and restart crane."
            )
        }

        alert.informativeText = lines.joined(separator: "\n\n")
        alert.runModal()
    }

    @MainActor
    static func presentSaveFailed(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t save your drop"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    @MainActor
    static func presentEphemeralStore() {
        presentLaunchWarnings(hotkeyFailed: false, ephemeralStore: true)
    }

    @MainActor
    static func presentHotkeyRegistrationFailed() {
        presentLaunchWarnings(hotkeyFailed: true, ephemeralStore: false)
    }
}
