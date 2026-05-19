//
//  FoundationModelsService.swift
//  crane
//
//  On-device tagging via Apple Intelligence's content-tagging adapter.
//

import Foundation
import FoundationModels
import os

@Generable
struct DropTagsResult {
    @Guide(description: "Most important topics in the input text.", .maximumCount(2))
    let topics: [String]
}

@MainActor
final class FoundationModelsService: AIService {

    static let shared = FoundationModelsService()

    private static let log = Logger(subsystem: "com.abhaycs.crane", category: "FoundationModels")

    private let taggingModel = SystemLanguageModel(useCase: .contentTagging)
    private var didPrewarm = false

    private init() {}

    var tagAvailability: AIAvailability {
        switch taggingModel.availability {
        case .available:
            if !taggingModel.supportsLocale() {
                return .unavailable("Apple Intelligence doesn’t support this language yet.")
            }
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable("Requires a Mac with Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in System Settings.")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence model is downloading…")
        case .unavailable:
            return .unavailable("Apple Intelligence is unavailable.")
        }
    }

    /// True when the OS inference provider recently crashed; queue should back off.
    static func isInferenceProviderCrash(_ error: Error) -> Bool {
        let text = String(describing: error).lowercased()
        return text.contains("inference provider crashed")
            || text.contains("modelmanagererror")
            || text.contains("generativeexperiencesd")
    }

    func extractTags(from text: String) async throws -> [String] {
        guard case .available = tagAvailability else { return [] }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Very short notes tag best with topics only (per Apple’s content-tagging guidance).
        let session = LanguageModelSession(model: taggingModel)
        if !didPrewarm {
            session.prewarm()
            didPrewarm = true
            // Prewarm needs ~1s before respond (per Apple docs).
            try? await Task.sleep(for: .seconds(1))
        }

        let response = try await session.respond(
            to: trimmed,
            generating: DropTagsResult.self
        )

        return TagExtractor.normalize(topics: response.content.topics, actions: [])
    }
}

extension FoundationModelsService {
    static func logFailure(_ error: Error, dropID: UUID) {
        log.error("Tagging failed for drop \(dropID.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
    }
}
