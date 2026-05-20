//
//  SingleInstance.swift
//  crane
//
//  Ensures only one crane process uses the shared SwiftData store at a time.
//

import AppKit
import Darwin

enum SingleInstance {

    private static var lockFileHandle: FileHandle?
    private static var lockFD: Int32 = -1

    /// Acquires an exclusive lock file, or activates an existing instance and
    /// returns `true` so the caller should terminate this launch.
    @MainActor
    static func shouldTerminateAsDuplicate() -> Bool {
        if acquireExclusiveLock() {
            return false
        }
        if activateExistingInstance() {
            return true
        }

        // Stale lock with no peer: clear and retry once.
        let url = lockFileURL()
        clearStaleLockIfNeeded(at: url)
        try? FileManager.default.removeItem(at: url)
        if acquireExclusiveLock() {
            return false
        }

        CraneAlert.presentInstanceLockFailed()
        return true
    }

    /// Releases the lock file. Call from `applicationWillTerminate`.
    static func releaseLock() {
        if lockFD >= 0 {
            flock(lockFD, LOCK_UN)
            close(lockFD)
            lockFD = -1
        }
        try? lockFileHandle?.close()
        lockFileHandle = nil
    }

    // MARK: - Lock file

    private static func lockFileURL() -> URL {
        Persistence.applicationSupportDirectory()
            .appending(path: "crane.instance.lock", directoryHint: .notDirectory)
    }

    @MainActor
    private static func acquireExclusiveLock() -> Bool {
        let url = lockFileURL()
        clearStaleLockIfNeeded(at: url)
        FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)

        guard let handle = try? FileHandle(forWritingTo: url) else { return false }
        let fd = handle.fileDescriptor
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            try? handle.close()
            return false
        }

        lockFileHandle = handle
        lockFD = fd
        let pidData = "\(ProcessInfo.processInfo.processIdentifier)\n".data(using: .utf8)
        try? handle.truncate(atOffset: 0)
        if let pidData {
            try? handle.write(contentsOf: pidData)
        }
        return true
    }

    /// Removes a lock file left behind when a previous process crashed.
    private static func clearStaleLockIfNeeded(at url: URL) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }

        if kill(pid, 0) != 0, errno == ESRCH {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @MainActor
    private static func activateExistingInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let pid = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != pid }
        guard let existing = others.first else { return false }
        existing.activate(options: [.activateIgnoringOtherApps])
        return true
    }
}
