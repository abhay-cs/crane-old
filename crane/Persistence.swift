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

    /// Maximum characters saved per drop (capture + paste guard).
    static let maxDropTextLength = 8_192

    /// Upper bound for `@Query` fetches in dashboard and history.
    static let maxFetchedDrops = 5_000

    /// Lazily-built container shared by every surface in the app. Built
    /// once on first access (which is the main actor in practice, since
    /// both the `MenuBarExtra` scene and `OverlayController.attach` run
    /// on the main actor) and reused for the process lifetime.
    static let container: ModelContainer = makeContainer()

    /// `true` when the on-disk store failed to open and an in-memory
    /// fallback is in use (drops are lost on quit).
    static private(set) var isEphemeralStore = false

    /// Path to the most recent archived corrupt store, if recovery ran.
    static private(set) var lastArchivedStorePath: String?

    /// Human-readable store location for support / alert copy.
    static var storeDirectoryPath: String {
        applicationSupportDirectory().path(percentEncoded: false)
    }

    // MARK: - Container

    private static func openDiskContainer(config: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Drop.self,
            migrationPlan: CraneMigrationPlan.self,
            configurations: config
        )
    }

    private static func openEphemeralContainer() throws -> ModelContainer {
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Drop.self,
            migrationPlan: CraneMigrationPlan.self,
            configurations: memory
        )
    }

    private static func makeContainer() -> ModelContainer {
        let storeURL = applicationSupportDirectory()
            .appending(path: "crane.store", directoryHint: .notDirectory)
        let config = ModelConfiguration(url: storeURL)

        do {
            let container = try openDiskContainer(config: config)
            migrateLegacyJSONIfNeeded(into: container.mainContext, persistToDisk: true)
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
                migrateLegacyJSONIfNeeded(into: recovered.mainContext, persistToDisk: true)
                return recovered
            }

            isEphemeralStore = true
            do {
                let ephemeral = try openEphemeralContainer()
                // Session-only import; never rename drops.json while ephemeral.
                migrateLegacyJSONIfNeeded(into: ephemeral.mainContext, persistToDisk: false)
                return ephemeral
            } catch {
                fatalError("crane: unable to create in-memory SwiftData store: \(error)")
            }
        }
    }

    /// Archives a broken on-disk store, then retries opening once.
    private static func attemptStoreRecovery(
        storeURL: URL,
        config: ModelConfiguration,
        originalError: Error
    ) -> ModelContainer? {
        #if DEBUG
        print("crane: attempting store recovery after: \(originalError)")
        #endif

        lastArchivedStorePath = archiveBrokenStore(at: storeURL)?.path(percentEncoded: false)

        return try? openDiskContainer(config: config)
    }

    /// Moves store files into `crane.store.corrupt.<timestamp>/` before delete-retry.
    @discardableResult
    private static func archiveBrokenStore(at storeURL: URL) -> URL? {
        let fm = FileManager.default
        let parent = storeURL.deletingLastPathComponent()
        let stamp = Int(Date().timeIntervalSince1970)
        let archiveDir = parent.appending(path: "crane.store.corrupt.\(stamp)", directoryHint: .isDirectory)

        let sidecars = ["", "-shm", "-wal"].map { suffix in
            URL(fileURLWithPath: storeURL.path(percentEncoded: false) + suffix)
        }

        var movedAny = false
        do {
            try fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)
            for url in sidecars where fm.fileExists(atPath: url.path(percentEncoded: false)) {
                let dest = archiveDir.appending(path: url.lastPathComponent)
                if fm.fileExists(atPath: dest.path(percentEncoded: false)) {
                    try fm.removeItem(at: dest)
                }
                try fm.moveItem(at: url, to: dest)
                movedAny = true
            }
        } catch {
            #if DEBUG
            print("crane: failed to archive corrupt store: \(error)")
            #endif
            for url in sidecars {
                try? fm.removeItem(at: url)
            }
            return nil
        }

        return movedAny ? archiveDir : nil
    }

    // MARK: - Paths

    static func applicationSupportDirectory() -> URL {
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

    /// Shape of the rows stored by the previous `DropsStore` JSON file.
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

    /// Merges `drops.json` rows missing from SwiftData (by UUID). Renames the
    /// JSON file only when every row is present and `persistToDisk` is true.
    private static func migrateLegacyJSONIfNeeded(
        into context: ModelContext,
        persistToDisk: Bool
    ) {
        let supportDir = applicationSupportDirectory()
        let jsonURL = supportDir
            .appending(path: "drops.json", directoryHint: .notDirectory)
        let migratedURL = supportDir
            .appending(path: "drops.json.migrated", directoryHint: .notDirectory)

        guard FileManager.default.fileExists(atPath: jsonURL.path(percentEncoded: false)) else {
            return
        }

        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacy = try decoder.decode([LegacyDrop].self, from: data)
            guard !legacy.isEmpty else {
                if persistToDisk {
                    try? FileManager.default.moveItem(at: jsonURL, to: migratedURL)
                }
                return
            }

            let existingIDs = try fetchAllDropIDs(in: context)
            var inserted = 0

            for row in legacy {
                guard !existingIDs.contains(row.id) else { continue }
                let type = DropType(rawValue: row.drop_type) ?? .thought
                let text = String(row.text.prefix(maxDropTextLength))
                context.insert(
                    Drop(
                        id: row.id,
                        text: text,
                        dropType: type,
                        timestamp: row.timestamp,
                        sourceApp: row.sourceApp
                    )
                )
                inserted += 1
            }

            if inserted > 0 {
                try context.save()
            }

            let idsAfterImport = try fetchAllDropIDs(in: context)
            let allPresent = legacy.allSatisfy { idsAfterImport.contains($0.id) }

            if allPresent && persistToDisk {
                try? FileManager.default.moveItem(at: jsonURL, to: migratedURL)
            }
        } catch {
            // Leave drops.json in place so a future launch can try again.
            #if DEBUG
            print("crane: legacy JSON migration failed: \(error)")
            #endif
        }
    }

    private static func fetchAllDropIDs(in context: ModelContext) throws -> Set<UUID> {
        var ids = Set<UUID>()
        let batchSize = 500
        var offset = 0

        while true {
            var descriptor = FetchDescriptor<Drop>()
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset
            let batch = try context.fetch(descriptor)
            guard !batch.isEmpty else { break }
            for drop in batch {
                ids.insert(drop.id)
            }
            if batch.count < batchSize { break }
            offset += batchSize
        }

        return ids
    }
}
