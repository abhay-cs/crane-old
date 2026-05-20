//
//  ModelContext+DropDeletion.swift
//  crane
//

import SwiftData

extension ModelContext {

    /// Deletes a drop and persists, rolling back the context if save fails.
    @MainActor
    func deleteDrop(_ drop: Drop) {
        delete(drop)
        do {
            try save()
        } catch {
            rollback()
            CraneAlert.presentSaveFailed(error)
        }
    }
}
