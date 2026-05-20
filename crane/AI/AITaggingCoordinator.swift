//
//  AITaggingCoordinator.swift
//  crane
//
//  Re-runs tag backfill when Apple Intelligence becomes available after launch.
//

import AppKit
import Foundation

@MainActor
final class AITaggingCoordinator {

    static let shared = AITaggingCoordinator()

    private var lastAvailability: AIAvailability?
    private var activeObserver: NSObjectProtocol?

    private init() {}

    func startObserving() {
        guard activeObserver == nil else { return }

        lastAvailability = FoundationModelsService.shared.tagAvailability

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAndBackfillIfNeeded()
        }

        checkAndBackfillIfNeeded()
    }

    func stopObserving() {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
    }

    func checkAndBackfillIfNeeded() {
        let service = FoundationModelsService.shared
        let current = service.tagAvailability
        defer { lastAvailability = current }

        guard case .available = current else { return }

        let wasAvailable: Bool
        if case .available = lastAvailability {
            wasAvailable = true
        } else {
            wasAvailable = false
        }

        guard !wasAvailable || AIJobQueue.shared.hasUntaggedWork else { return }
        AIJobQueue.shared.backfillUntaggedDrops(limit: 20)
    }
}
