//
//  OnboardingVerifier.swift
//  crane
//
//  Automated runtime checks for the first-run tour, mirroring
//  OverlayGlassVerifier: launch with CRANE_VERIFY_ONBOARDING=1 (see
//  scripts/test-onboarding.sh) to drive the real controller through every
//  step via the same events the app posts, then write JSON and exit.
//

import AppKit

enum OnboardingVerifier {

    struct Result: Encodable {
        let passed: Bool
        let failures: [String]
        let glass: OverlayGlassVerifier.Result?
    }

    /// Drives the tour end to end. Step changes land one main-queue turn
    /// after each event (the controller observes with `queue: .main`), so
    /// the sequence yields between actions.
    @MainActor
    static func run(
        onboarding: OnboardingController,
        overlay: OverlayController
    ) async -> Result {
        var failures: [String] = []

        func check(_ condition: Bool, _ label: String) {
            if !condition { failures.append(label) }
        }
        func tick() async {
            try? await Task.sleep(for: .milliseconds(150))
        }

        // Verification completes the tour, which persists the flag; put the
        // user's real first-run state back afterwards.
        let priorFlag = UserDefaults.standard.object(forKey: OnboardingController.completedDefaultsKey)
        defer {
            if priorFlag == nil {
                UserDefaults.standard.removeObject(forKey: OnboardingController.completedDefaultsKey)
            } else {
                UserDefaults.standard.set(priorFlag, forKey: OnboardingController.completedDefaultsKey)
            }
        }

        onboarding.show()
        await tick()
        check(onboarding.isVisible, "card visible after show()")
        check(onboarding.step == .capture, "step starts at capture")

        // Glass wrap + panel size (catches Auto Layout ballooning the frame).
        var glassResult: OverlayGlassVerifier.Result?
        if let panel = onboarding.panelForTesting {
            let result = OverlayGlassVerifier.verify(
                window: panel,
                expectedContainerSize: OnboardingController.panelSize,
                margin: DesignMetrics.glassShadowMargin,
                label: "onboarding"
            )
            glassResult = result
            check(result.passed, "glass host checks: \(result.failures.joined(separator: "; "))")
        } else {
            check(false, "onboarding panel exists")
        }

        overlay.show() // the ⌘⇧Space path — posts .craneOverlayDidShow
        await tick()
        check(onboarding.step == .save, "overlay show advances to save")

        overlay.hide() // Esc without saving rewinds the instruction
        await tick()
        check(onboarding.step == .capture, "overlay hide rewinds to capture")

        overlay.show()
        await tick()
        NotificationCenter.default.post(name: .craneDropDidSave, object: nil)
        await tick()
        check(onboarding.step == .review, "drop save advances to review")

        onboarding.finish()
        await tick()
        check(!onboarding.isVisible, "card hidden after finish()")
        check(OnboardingController.hasCompleted, "completion flag persisted")

        // Replay path (Capture → Welcome Tour) restarts from step one.
        onboarding.show()
        await tick()
        check(onboarding.isVisible, "replay shows card again")
        check(onboarding.step == .capture, "replay restarts at capture")
        onboarding.finish()
        overlay.hide()

        return Result(
            passed: failures.isEmpty,
            failures: failures,
            glass: glassResult
        )
    }
}
