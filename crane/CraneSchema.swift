//
//  CraneSchema.swift
//  crane
//
//  Versioned SwiftData schema for forward-compatible migrations. v1 matches
//  the initial ship model; add CraneSchemaV2 + a MigrationStage before
//  changing `Drop` in production.
//
//  Note: adding optional attributes (e.g. `tags`, `aiProcessedAt`) with
//  inline defaults is handled by SwiftData automatically — do not register
//  a second VersionedSchema for the same `@Model` type or the container
//  crashes with "Duplicate version checksums detected."
//

import SwiftData

enum CraneSchemaV1: VersionedSchema {
  static var versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [Drop.self]
  }
}

enum CraneMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [CraneSchemaV1.self]
  }

  static var stages: [MigrationStage] {
    []
  }
}
