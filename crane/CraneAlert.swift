//
//  CraneAlert.swift
//  crane
//
//  AppKit alerts for errors that SwiftUI surfaces cannot easily show from
//  a borderless overlay (save failures, persistence, hotkey registration).
//

import AppKit

enum CraneAlert {

  @MainActor
  static func presentSaveFailed(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "Couldn’t save your drop"
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.runModal()
  }

  @MainActor
  static func presentInvalidLink() {
    let alert = NSAlert()
    alert.messageText = "That doesn’t look like a link"
    alert.informativeText = "Enter a URL (for example https://example.com) or turn off link mode with ⌘L."
    alert.alertStyle = .warning
    alert.runModal()
  }

  @MainActor
  static func presentEphemeralStore() {
    let storePath = Persistence.storeDirectoryPath
    let alert = NSAlert()
    alert.messageText = "crane can’t access its database"
    alert.informativeText =
      "Your drops will only be kept until you quit. "
      + "Quit other copies of crane, then restart. "
      + "If this keeps happening, remove the store files in:\n\n"
      + storePath + "\n\n"
      + "(delete crane.store and any crane.store-shm / crane.store-wal files). "
      + "If drops.json is still there, crane will re-import it on the next launch."
    alert.alertStyle = .critical
    alert.runModal()
  }

  @MainActor
  static func presentHotkeyRegistrationFailed() {
    let alert = NSAlert()
    alert.messageText = "Global shortcut unavailable"
    alert.informativeText =
      "crane couldn’t register ⌘⇧Space. Another app may be using that combo. "
      + "Open the menu-bar window and choose New Drop, or quit the conflicting app and restart crane."
    alert.alertStyle = .warning
    alert.runModal()
  }
}
