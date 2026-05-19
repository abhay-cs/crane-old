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

    /// Human-readable store location for support / alert copy.
    static var storeDirectoryPath: String {
        applicationSupportDirectory().path(percentEncoded: false)
    }

    // MARK: - Container

    private static func openDiskContainer(config: ModelConfiguration) throws -> ModelContainer {
        // Additive schema changes (new optional/defaulted fields) migrate
        // automatically; an explicit plan is only needed for custom stages.
        try ModelContainer(for: Drop.self, configurations: config)
    }

    private static func makeContainer() -> ModelContainer {
        let storeURL = applicationSupportDirectory()
            .appending(path: "crane.store", directoryHint: .notDirectory)
        let config = ModelConfiguration(url: storeURL)

        do {
            let container = try openDiskContainer(config: config)
            migrateLegacyJSONIfNeeded(into: container.mainContext)
            return container
        } catch {
            let storeError = error
            #if DEBUG
            print("crane: failed to open SwiftData store at \(storeURL.path): \(storeError)")
            #endif

            if let recovered = attemptStoreRecovery(
                storeURL: storeURL,
                config: config,
                originalError: storeError
            ) {
                migrateLegacyJSONIfNeeded(into: recovered.mainContext)
                return recovered
            }

            // If the on-disk store is corrupt or unreadable, fall back to
            // an in-memory container so the app still launches. The user's
            // legacy `drops.json` (if any) is left in place so a later
            // launch can retry the migration once the store is fixed.
            isEphemeralStore = true
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            let ephemeral = try! ModelContainer(for: Drop.self, configurations: memory)
            migrateLegacyJSONIfNeeded(into: ephemeral.mainContext)
            return ephemeral
        }
    }

    /// Deletes a broken on-disk store (and SQLite sidecars) and retries once.
    private static func attemptStoreRecovery(
        storeURL: URL,
        config: ModelConfiguration,
        originalError: Error
    ) -> ModelContainer? {
        #if DEBUG
        print("crane: attempting store recovery after: \(originalError)")
        #endif

        removeStoreFiles(at: storeURL)

        return try? openDiskContainer(config: config)
    }

    private static func removeStoreFiles(at storeURL: URL) {
        let fm = FileManager.default
        let sidecars = ["", "-shm", "-wal"].map { suffix in
            URL(fileURLWithPath: storeURL.path(percentEncoded: false) + suffix)
        }
        for url in sidecars {
            try? fm.removeItem(at: url)
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
