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

    @MainActor
    static func presentInstanceLockFailed() {
        let alert = NSAlert()
        alert.messageText = "crane couldn’t start safely"
        alert.informativeText =
            "Another copy may still be running, or a stale lock file is blocking launch. "
            + "Quit all crane processes, then delete:\n\n"
            + Persistence.applicationSupportDirectory()
                .appending(path: "crane.instance.lock", directoryHint: .notDirectory)
                .path(percentEncoded: false)
        alert.alertStyle = .critical
        alert.runModal()
    }

    @MainActor
    static func presentHotkeyLostAfterWake() {
        let alert = NSAlert()
        alert.messageText = "Global shortcut stopped working"
        alert.informativeText =
            "crane couldn’t re-register ⌘⇧Space after your Mac woke up. "
            + "Use New Drop from the menu bar, or quit and reopen crane."
        alert.alertStyle = .warning
        alert.runModal()
    }

    /// Returns `true` when the user confirms deleting all entries.
    @MainActor
    static func confirmResetAllData() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Delete all entries?"
        alert.informativeText =
            "Every thought and link in crane will be removed. This can’t be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete All")
        if let deleteButton = alert.buttons.last {
            deleteButton.hasDestructiveAction = true
        }
        return alert.runModal() == .alertSecondButtonReturn
    }
}
