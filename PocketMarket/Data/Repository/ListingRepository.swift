//
//  ListingRepository.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Single source of truth for listing data. Reads always come from Core Data
//  (so the UI works identically online or offline); writes go to Core Data
//  immediately (optimistic) and are queued for the SyncEngine to replay
//  against the network when connectivity allows.
//

import Foundation
import CoreData
import Combine
import os

private let logger = Logger(subsystem: "com.offlinemarketplace", category: "Repository")

final class ListingRepository: ListingRepositoryProtocol {
    private let persistence: PersistenceController
    private let networkService: NetworkServiceProtocol
    private let syncEngine: SyncEngine

    private let listingsSubject = CurrentValueSubject<[Listing], Never>([])
    var listingsPublisher: AnyPublisher<[Listing], Never> { listingsSubject.eraseToAnyPublisher() }

    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> { syncEngine.statusPublisher }

    init(persistence: PersistenceController = .shared,
         networkService: NetworkServiceProtocol,
         syncEngine: SyncEngine) {
        self.persistence = persistence
        self.networkService = networkService
        self.syncEngine = syncEngine

        // When the SyncEngine finishes a background sync (e.g. triggered by
        // WiFi reconnecting), re-emit listings so the UI reflects the updated
        // syncState (pendingCreate → synced, etc.).
        syncEngine.onSyncComplete = { [weak self] in
            logger.notice("onSyncComplete fired — re-emitting from Core Data")
            Task {
                await self?.emitFromLocalStore()
                logger.notice("emitFromLocalStore completed after sync callback")
            }
        }
    }

    func loadListings() async {
        await emitFromLocalStore()
        // Kick a background refresh but don't block the initial (instant,
        // offline-capable) render on it.
        Task { try? await refresh() }
    }

    func refresh() async throws {
        let remoteDTOs = try await networkService.fetchListings()
        try await mergeRemote(remoteDTOs)
        await emitFromLocalStore()
        // Also drain any pending changes (pull-to-refresh is a natural
        // trigger point — if the user just turned WiFi back on, this
        // ensures queued offline changes sync even if the NWPathMonitor
        // event was missed).
        await syncEngine.syncIfPossible()
        await emitFromLocalStore()
    }

    func toggleFavorite(listingId: String) async {
        let context = persistence.backgroundContext
        await context.perform {
            let request: NSFetchRequest<ListingEntity> = ListingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listingId)
            guard let entity = try? context.fetch(request).first else { return }

            entity.isFavorite.toggle()
            entity.updatedAt = Date()
            entity.version += 1
            entity.syncState = SyncState.pendingUpdate.rawValue

            self.enqueuePendingChange(
                for: entity.toDomain(), operation: .toggleFavorite, in: context
            )
            try? context.save()
        }
        await emitFromLocalStore()
        await syncEngine.syncIfPossible()
        // Re-emit so the badge updates from .pendingUpdate → .synced
        await emitFromLocalStore()
    }

    func createListing(_ draft: NewListingDraft) async throws {
        let context = persistence.backgroundContext
        let newListing = Listing(
            id: UUID().uuidString,
            title: draft.title,
            description: draft.description,
            price: draft.price,
            currency: "CAD",
            category: draft.category,
            condition: draft.condition,
            imageURL: nil,
            thumbnailURL: nil,
            localImagePath: draft.localImagePath,
            sellerId: "current_user", // stand-in for an authenticated user id
            location: "Unknown",
            createdAt: Date(),
            updatedAt: Date(),
            isFavorite: false,
            version: 1,
            syncState: .pendingCreate
        )

        try await context.perform {
            let entity = ListingEntity(context: context)
            entity.apply(newListing)
            self.enqueuePendingChange(for: newListing, operation: .create, in: context)
            try context.save()
        }

        await emitFromLocalStore()
        await syncEngine.syncIfPossible()
        // Re-emit after sync so the UI reflects the updated syncState
        // (e.g. .pendingCreate → .synced). Without this second emit the
        // Combine publisher keeps the stale pre-sync snapshot.
        await emitFromLocalStore()
    }

    func syncPendingChanges() async {
        await syncEngine.syncIfPossible()
        await emitFromLocalStore()
    }

    // MARK: - Private

    private func enqueuePendingChange(for listing: Listing, operation: PendingOperation, in context: NSManagedObjectContext) {
        let change = PendingChangeEntity(context: context)
        change.id = UUID().uuidString
        change.listingId = listing.id
        change.operation = operation.rawValue
        change.payload = (try? JSONEncoder().encode(listing.toDTO())) ?? Data()
        change.localImagePath = listing.localImagePath
        change.createdAt = Date()
        change.retryCount = 0
    }

    /// Merges a remote fetch into local storage, applying last-write-wins
    /// conflict resolution against any record that has local pending changes
    /// (so a background refresh can never silently clobber an offline edit).
    private func mergeRemote(_ remoteDTOs: [ListingDTO]) async throws {
        let context = persistence.backgroundContext
        try await context.perform {
            let request: NSFetchRequest<ListingEntity> = ListingEntity.fetchRequest()
            let existing = (try? context.fetch(request)) ?? []
            var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id ?? "", $0) })

            for dto in remoteDTOs {
                let remote = dto.toDomain()
                if let entity = existingByID[dto.id] {
                    let local = entity.toDomain()
                    if local.syncState != .synced {
                        // Local has unsynced work — resolve instead of overwrite.
                        let resolved = ConflictResolver.resolve(local: local, remote: remote)
                        entity.apply(resolved)
                    } else {
                        entity.apply(remote)
                    }
                    existingByID.removeValue(forKey: dto.id)
                } else {
                    let entity = ListingEntity(context: context)
                    entity.apply(remote)
                }
            }
            try context.save()
        }
    }

    private func emitFromLocalStore() async {
        let context = persistence.backgroundContext
        let listings: [Listing] = await context.perform {
            let request: NSFetchRequest<ListingEntity> = ListingEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let entities = (try? context.fetch(request)) ?? []
            return entities.map { $0.toDomain() }
        }
        listingsSubject.send(listings)
    }
}


