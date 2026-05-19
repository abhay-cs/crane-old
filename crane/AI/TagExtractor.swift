//
//  TagExtractor.swift
//  crane
//
//  Normalizes model output into display-ready tag strings for `Drop.tags`.
//

import Foundation

enum TagExtractor {

    /// Flattens topic/action lists, lowercases, dedupes, and caps count.
    static func normalize(topics: [String], actions: [String], limit: Int = 3) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in topics + actions {
            let tag = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !tag.isEmpty else { continue }
            guard seen.insert(tag).inserted else { continue }
            result.append(tag)
            if result.count >= limit { break }
        }

        return result
    }
}
