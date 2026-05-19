//
//  Persistence.swift
//  crane
//
//  Owns the single shared `ModelContainer` for the app and runs a one-time
//  migration from the legacy `drops.json` JSON store the first time a
//  SwiftData container comes up empty. Both the `MenuBarExtra` dashboard
//  and the floating overlay panel point at the same container, so writes
//  in the input bar surface live in the dashboard immediately via
//  `@Query` observation.
//

import Foundation
import SwiftData

enum Persistence {

    /// Lazily-built container shared by every surface in the app. Built
    /// once on first access (which is the main actor in practice, since
    /// both the `MenuBarExtra` scene and `OverlayController.attach` run
    /// on the main actor) and reused for the process lifetime.
    static let container: ModelContainer = makeContainer()

    /// `true` when the on-disk store failed to open and an in-memory
    /// fallback is in use (drops are lost on quit).
    static private(set) var isEphemeralStore = false

    // MARK: - Container

    private static func makeContainer() -> ModelContainer {
        let storeURL = applicationSupportDirectory()
            .appending(path: "crane.store", directoryHint: .notDirectory)
        let config = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(
                for: Drop.self,
                migrationPlan: CraneMigrationPlan.self,
                configurations: config
            )
            migrateLegacyJSONIfNeeded(into: container.mainContext)
            return container
        } catch {
            // If the on-disk store is corrupt or unreadable, fall back to
            // an in-memory container so the app still launches. The user's
            // legacy `drops.json` (if any) is left in place so a later
            // launch can retry the migration once the store is fixed.
            isEphemeralStore = true
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(
                for: Drop.self,
                migrationPlan: CraneMigrationPlan.self,
                configurations: memory
            )
        }
    }

    // MARK: - Paths

    private static func applicationSupportDirectory() -> URL {
        let fm = FileManager.default
        let bundleID = Bundle.main.bundleIdentifier ?? "com.abhaycs.crane"

        let baseDir: URL
        do {
            baseDir = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            baseDir = fm.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }

        let dir = baseDir.appending(path: bundleID, directoryHint: .isDirectory)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Legacy JSON migration

    /// Shape of the rows stored by the previous `DropsStore` JSON file —
    /// kept here so the active `Drop` model can shed `Codable` and the
    /// `drop_type` / `source_app` snake_case coding keys.
    private struct LegacyDrop: Decodable {
        let id: UUID
        let text: String
        let drop_type: String
        let timestamp: Date
        let sourceApp: String?

        enum CodingKeys: String, CodingKey {
            case id, text, timestamp
            case drop_type
            case sourceApp = "source_app"
        }
    }

    /// If a `drops.json` file from the JSON-backed era exists and the
    /// SwiftData store has no rows yet, decode the JSON, insert each row,
    /// and rename the file to `drops.json.migrated` so this never runs
    /// twice. Best-effort: any failure leaves the JSON in place for a
    /// retry on a future launch.
    private static func migrateLegacyJSONIfNeeded(into context: ModelContext) {
        let supportDir = applicationSupportDirectory()
        let jsonURL = supportDir
            .appending(path: "drops.json", directoryHint: .notDirectory)
        let migratedURL = supportDir
            .appending(path: "drops.json.migrated", directoryHint: .notDirectory)

        guard FileManager.default.fileExists(atPath: jsonURL.path(percentEncoded: false)) else {
            return
        }

        // Only seed when the SwiftData store is empty, so deleting all
        // drops in the UI and relaunching doesn't resurrect them.
        let existingCount: Int
        do {
            existingCount = try context.fetchCount(FetchDescriptor<Drop>())
        } catch {
            return
        }
        guard existingCount == 0 else { return }

        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacy = try decoder.decode([LegacyDrop].self, from: data)

            for row in legacy {
                let type = DropType(rawValue: row.drop_type) ?? .thought
                context.insert(
                    Drop(
                        id: row.id,
                        text: row.text,
                        dropType: type,
                        timestamp: row.timestamp,
                        sourceApp: row.sourceApp
                    )
                )
            }
            try context.save()
            try? FileManager.default.moveItem(at: jsonURL, to: migratedURL)
        } catch {
            // Leave drops.json in place so a future launch can try again.
        }
    }
}
