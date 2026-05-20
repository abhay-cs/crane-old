//
//  AIJobQueue.swift
//  crane
//
//  Serial background processor for FM tag extraction. Never blocks capture.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AIJobQueue {

    static let shared = AIJobQueue()

    private let service: AIService = FoundationModelsService.shared
    private var pending: [UUID] = []
    private var isRunning = false

    /// Drops waiting in the serial queue (for dashboard “Tagging…” UI).
    private(set) var pendingCount = 0
    /// A tag-extraction job is in flight.
    private(set) var isProcessing = false

    /// Active only when FM is available and work is queued or running.
    var isActive: Bool {
        guard case .available = service.tagAvailability else { return false }
        return isProcessing || pendingCount > 0
    }

    private var cooldownUntil: Date?
    private var lastRequestFinishedAt: Date?

    /// Pause after an inference-provider crash so we don’t hammer `generativeexperiencesd`.
    private static let providerCrashCooldown: TimeInterval = 300
    /// Minimum gap between FM calls to avoid concurrent-request / rate-limit errors.
    private static let minimumRequestInterval: TimeInterval = 1.0

    private init() {}

    var isPaused: Bool {
        if let cooldownUntil, cooldownUntil > Date() { return true }
        return false
    }

    func enqueue(dropID: UUID) {
        guard case .available = service.tagAvailability else { return }
        guard !pending.contains(dropID) else { return }
        pending.append(dropID)
        syncPublishedState()
        drain()
    }

    /// Tags untagged drops, capped and staggered so launch doesn’t flood the inference provider.
    func backfillUntaggedDrops(limit: Int = 10) {
        guard case .available = service.tagAvailability else { return }
        guard !isPaused else { return }

        let context = Persistence.container.mainContext
        var descriptor = FetchDescriptor<Drop>(
            predicate: #Predicate { $0.aiProcessedAt == nil },
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        guard let drops = try? context.fetch(descriptor) else { return }
        for drop in drops {
            enqueue(dropID: drop.id)
        }
    }

    private func drain() {
        guard !isRunning, !pending.isEmpty else { return }

        guard case .available = service.tagAvailability else {
            pending.removeAll()
            syncPublishedState()
            return
        }

        if let cooldownUntil, cooldownUntil > Date() {
            scheduleDrain(after: cooldownUntil.timeIntervalSinceNow)
            return
        }
        self.cooldownUntil = nil

        isRunning = true
        let dropID = pending.removeFirst()
        syncPublishedState()

        Task {
            await throttleIfNeeded()
            await process(dropID: dropID)
            lastRequestFinishedAt = Date()
            isRunning = false
            syncPublishedState()
            drain()
        }
    }

    private func syncPublishedState() {
        pendingCount = pending.count
        isProcessing = isRunning
    }

    private func throttleIfNeeded() async {
        guard let lastRequestFinishedAt else { return }
        let elapsed = Date().timeIntervalSince(lastRequestFinishedAt)
        let wait = Self.minimumRequestInterval - elapsed
        if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    private func process(dropID: UUID) async {
        let context = Persistence.container.mainContext

        var descriptor = FetchDescriptor<Drop>(
            predicate: #Predicate { $0.id == dropID }
        )
        descriptor.fetchLimit = 1

        guard let drop = try? context.fetch(descriptor).first else { return }
        guard drop.aiProcessedAt == nil else { return }

        do {
            let tags = try await service.extractTags(from: drop.text)
            drop.tags = tags
            drop.aiTaggingFailed = false
            drop.aiProcessedAt = Date()
            try context.save()
        } catch {
            FoundationModelsService.logFailure(error, dropID: dropID)

            if FoundationModelsService.isInferenceProviderCrash(error) {
                cooldownUntil = Date().addingTimeInterval(Self.providerCrashCooldown)
                pending.insert(dropID, at: 0)
                syncPublishedState()
                return
            }

            drop.tags = []
            drop.aiTaggingFailed = true
            drop.aiProcessedAt = Date()
            try? context.save()
        }
    }

    private func scheduleDrain(after interval: TimeInterval) {
        let delay = max(interval, 1)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            drain()
        }
    }
}
