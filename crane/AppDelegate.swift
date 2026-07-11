//
//  AppDelegate.swift
//  crane
//
//  Bridges SwiftUI `@main` with the AppKit pieces that have no SwiftUI
//  equivalent: hiding from Dock / Cmd-Tab, registering a global hotkey,
//  and owning the floating overlay panel.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) weak var shared: AppDelegate?

    private(set) lazy var overlay: OverlayController = OverlayController()
    private(set) lazy var onboarding: OnboardingController = OnboardingController()
    private let hotkey = GlobalHotkey()
    private var wakeObserver: NSObjectProtocol?
    private var hotkeyRegisteredSuccessfully = false

    // MARK: - NSApplicationDelegate

    private static let overlayGlassVerificationEnv = "CRANE_VERIFY_OVERLAY_GLASS"
    private static let onboardingVerificationEnv = "CRANE_VERIFY_ONBOARDING"

    private static var isOverlayGlassVerificationRun: Bool {
        ProcessInfo.processInfo.environment[overlayGlassVerificationEnv] == "1"
    }

    private static var isOnboardingVerificationRun: Bool {
        ProcessInfo.processInfo.environment[onboardingVerificationEnv] == "1"
    }

    private static var isVerificationRun: Bool {
        isOverlayGlassVerificationRun || isOnboardingVerificationRun
    }

    private static var verificationOutputURL: URL {
        Persistence.applicationSupportDirectory()
            .appendingPathComponent("overlay-glass-test.json", conformingTo: .json)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if !Self.isVerificationRun, SingleInstance.shouldTerminateAsDuplicate() {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        NSApp.setActivationPolicy(.accessory)
        // Pin the whole app (overlay panel + menu-bar dashboard) to dark so the
        // Liquid Glass surfaces render the same smoky tint regardless of the
        // user's system appearance. Without this the MenuBarExtra window adopts
        // the system (often light) appearance and its glass looks washed out.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        overlay.attach(rootView: ContentView())

        let hotkeyOK = registerHotkey()
        hotkeyRegisteredSuccessfully = hotkeyOK

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reregisterHotkeyAfterWake()
        }

        AITaggingCoordinator.shared.startObserving()

        if !Self.isVerificationRun {
            CraneAlert.presentLaunchWarnings(
                hotkeyFailed: !hotkeyOK,
                ephemeralStore: Persistence.isEphemeralStore
            )
            onboarding.showIfNeeded()
        }

        Task {
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run {
                AIJobQueue.shared.backfillUntaggedDrops(limit: 10)
            }
        }

        if Self.isOverlayGlassVerificationRun {
            runOverlayGlassVerificationAndTerminate()
            return
        }
        if Self.isOnboardingVerificationRun {
            runOnboardingVerificationAndTerminate()
            return
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        AITaggingCoordinator.shared.stopObserving()
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

    private func reregisterHotkeyAfterWake() {
        let ok = registerHotkey()
        if hotkeyRegisteredSuccessfully, !ok {
            CraneAlert.presentHotkeyLostAfterWake()
        }
        hotkeyRegisteredSuccessfully = ok
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

    /// Replays the first-run tour from the Capture menu.
    func showWelcomeTour() {
        onboarding.show()
    }

    /// Deletes every drop and clears overlay history state.
    func resetAllData() {
        let context = Persistence.container.mainContext
        context.deleteAllDrops()
        AIJobQueue.shared.cancelAll()
        overlay.clearScrollHighlight()
        overlay.historySearchQuery = nil
        if overlay.currentView == .history {
            overlay.currentView = .input
        }
    }

    /// Prompts for confirmation, then resets all data.
    func confirmAndResetAllData() {
        guard CraneAlert.confirmResetAllData() else { return }
        resetAllData()
    }

    private func runOverlayGlassVerificationAndTerminate() {
        let outputURL = Self.verificationOutputURL
        var results: [OverlayGlassVerifier.Result] = []

        overlay.show()
        results.append(overlay.verifyGlassSetupForTesting())

        overlay.openHistory()
        results.append(overlay.verifyGlassSetupForTesting())

        struct Payload: Encodable {
            let passed: Bool
            let results: [OverlayGlassVerifier.Result]
        }

        let passed = results.allSatisfy(\.passed)
        let payload = Payload(passed: passed, results: results)

        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: outputURL, options: .atomic)
        }

        exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    private func runOnboardingVerificationAndTerminate() {
        let outputURL = Persistence.applicationSupportDirectory()
            .appendingPathComponent("onboarding-test.json", conformingTo: .json)

        Task { @MainActor in
            let result = await OnboardingVerifier.run(onboarding: onboarding, overlay: overlay)

            if let data = try? JSONEncoder().encode(result) {
                try? data.write(to: outputURL, options: .atomic)
            }

            exit(result.passed ? EXIT_SUCCESS : EXIT_FAILURE)
        }
    }
}
