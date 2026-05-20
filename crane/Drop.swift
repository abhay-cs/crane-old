//
//  Drop.swift
//  crane
//
//  A single captured thought or link. Persisted via SwiftData (see
//  `Persistence.swift`); a one-time importer migrates any pre-existing
//  `drops.json` from the legacy JSON store on first launch.
//

import Foundation
import SwiftData

enum DropType: String, Codable, Hashable {
    case thought
    case link
}

@Model
final class Drop {
    /// Stable cross-launch identifier. We keep an explicit `UUID` (instead
    /// of relying on SwiftData's `PersistentIdentifier`) so the migration
    /// from `drops.json` can preserve each row's original id, and so the
    /// value is portable for logging or export.
    @Attribute(.unique) var id: UUID
    var text: String
    var dropType: DropType
    var timestamp: Date
    var sourceApp: String?

    /// FM-extracted tags, populated asynchronously after save.
    var tags: [String] = []
    /// Set when tagging completes (including empty tag lists).
    var aiProcessedAt: Date? = nil

    init(
        id: UUID = UUID(),
        text: String,
        dropType: DropType,
        timestamp: Date = Date(),
        sourceApp: String? = nil,
        tags: [String] = [],
        aiProcessedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.dropType = dropType
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.tags = tags
        self.aiProcessedAt = aiProcessedAt
    }
}
