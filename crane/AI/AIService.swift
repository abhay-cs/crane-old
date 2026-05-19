//
//  AIService.swift
//  crane
//
//  Protocol for on-device tagging. v1 implements Foundation Models only;
//  Ollama/Gemma fallbacks can conform later without changing the queue.
//

import Foundation

enum AIAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

@MainActor
protocol AIService: AnyObject {
    var tagAvailability: AIAvailability { get }
    func extractTags(from text: String) async throws -> [String]
}
