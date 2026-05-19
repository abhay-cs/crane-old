//
//  SingleInstance.swift
//  crane
//
//  Ensures only one crane process uses the shared SwiftData store at a time.
//

import AppKit

enum SingleInstance {

  /// If another instance is already running, activates it and returns `true`
  /// so the caller should terminate this launch.
  @MainActor
  static func shouldTerminateAsDuplicate() -> Bool {
    guard let bundleID = Bundle.main.bundleIdentifier else { return false }
    let pid = ProcessInfo.processInfo.processIdentifier
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .filter { $0.processIdentifier != pid }
    guard let existing = others.first else { return false }
    existing.activate(options: [.activateIgnoringOtherApps])
    return true
  }
}
