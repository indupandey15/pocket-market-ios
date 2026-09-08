//
//  PersistenceController.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Owns the Core Data stack. One background context for writes (so 200-item
//  batch inserts / sync writes never block the UI), one main context bound
//  to the view context for reads, merged automatically.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    /// Dedicated background context for all writes. Using a single serial
    /// background context (rather than `performBackgroundTask` per call)
    /// keeps write ordering deterministic, which matters for sync — we
    /// never want a "toggle favorite" and a "sync upload result" to race
    /// and undo each other.
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PocketMarket")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // In production this would report to crash/analytics rather
                // than crash outright, but a corrupt store during a take-home
                // demo is worth surfacing loudly and immediately.
                fatalError("Core Data failed to load store: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func saveBackgroundContext() {
        guard backgroundContext.hasChanges else { return }
        do {
            try backgroundContext.save()
        } catch {
            assertionFailure("Failed to save background context: \(error)")
        }
    }
}


