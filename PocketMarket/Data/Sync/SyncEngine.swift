//
//  SyncEngine.swift
//  PocketMarket
//  Created by Indu Pandey on 08/09/26.
//  Drains the PendingChangeEntity queue against the network, oldest first.
//  Runs whenever (a) connectivity comes back, (b) the app enters foreground,
//  or (c) a mutation is made while online. Never runs two drains concurrently.
//

import Foundation
import CoreData
import Combine
import UIKit
import os

private let logger = Logger(subsystem: "com.pocketmarket", category: "SyncEngine")

final class SyncEngine {
    private let persistence: PersistenceController
    private let networkService: NetworkServiceProtocol
    private let reachability: Reachability
    private var cancellables = Set<AnyCancellable>()

    private let statusSubject: CurrentValueSubject<SyncStatus, Never>
    var statusPublisher: AnyPublisher<SyncStatus, Never> { statusSubject.eraseToAnyPublisher() }

    /// Fires after the SyncEngine finishes processing changes (success or
    /// partial failure). Callers (e.g. the repository) use this to re-read
    /// Core Data and push updated listings to the UI.
    var onSyncComplete: (() -> Void)?

    private var isSyncing = false
    private let maxRetries = 5

    init(persistence: PersistenceController = .shared,
         networkService: NetworkServiceProtocol,
         reachability: Reachability = .shared) {
        self.persistence = persistence
        self.networkService = networkService
        self.reachability = reachability
        self.statusSubject = CurrentValueSubject(SyncStatus(state: .idle, pendingCount: 0, lastSyncedAt: nil))

        // Primary trigger: sync when connectivity changes.
        reachability.isConnectedPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                logger.notice("Reachability changed → connected=\(connected)")
                if connected {
                    Task { [weak self] in
                        logger.notice("Triggering syncIfPossible from reachability change")
                        await self?.syncIfPossible()
                    }
                } else {
                    self?.updateStatus(state: .offline)
                }
            }
            .store(in: &cancellables)

        // Fallback trigger: sync when app returns to foreground.
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                logger.notice("App entering foreground — triggering sync")
                Task { [weak self] in await self?.syncIfPossible() }
            }
            .store(in: &cancellables)

        // Periodic probe: every 10 seconds, force a fresh connectivity
        // check. NWPathMonitor on the simulator can miss WiFi reconnects;
        // this one-shot probe catches the stale state and updates the
        // publisher, which triggers the Combine subscription above.
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.reachability.recheckConnectivity()
            }
            .store(in: &cancellables)
    }

    /// Safe to call opportunistically (after every mutation, on app
    /// foreground, on connectivity change) — it's a no-op if already
    /// syncing, offline, or there's nothing queued.
    func syncIfPossible() async {
        logger.notice("syncIfPossible() — isSyncing=\(self.isSyncing), isConnected=\(self.reachability.isConnected)")
        guard !isSyncing else {
            logger.notice("Already syncing, skipping")
            return
        }
        guard reachability.isConnected else {
            logger.notice("Offline, skipping")
            updateStatus(state: .offline)
            return
        }

        let pending = await fetchPendingChanges()
        logger.notice("Found \(pending.count) pending change(s)")
        guard !pending.isEmpty else {
            updateStatus(state: .idle, pendingCount: 0)
            return
        }

        isSyncing = true
        updateStatus(state: .syncing, pendingCount: pending.count)

        // Mark all pending listings as .syncing so the UI shows the
        // "Syncing" badge on each card during the upload.
        for change in pending {
            await markSyncing(listingId: change.listingId)
        }
        onSyncComplete?()  // emit updated .syncing state to UI

        for change in pending {
            do {
                logger.notice("Applying \(change.operation.rawValue) for \(change.listingId)")
                try await apply(change)
                await remove(change)
                logger.notice("✅ Synced \(change.listingId)")
            } catch {
                logger.error("❌ Failed \(change.listingId): \(error.localizedDescription)")
                await recordFailure(change, error: error)
            }
        }

        isSyncing = false
        let remaining = await fetchPendingChanges()
        logger.notice("Sync pass done — \(remaining.count) remaining")
        if remaining.isEmpty {
            updateStatus(state: .idle, pendingCount: 0, lastSyncedAt: Date())
        } else {
            updateStatus(state: .error("Some changes failed to sync"), pendingCount: remaining.count)
        }
        // Notify the repository to re-emit listings so the UI reflects
        // updated syncState values (e.g. syncing → synced).
        logger.notice("Firing onSyncComplete (callback set: \(self.onSyncComplete != nil))")
        onSyncComplete?()
    }

    // MARK: - Private

    private func apply(_ change: PendingChange) async throws {
        let dto = try JSONDecoder().decode(ListingDTO.self, from: change.payload)

        switch change.operation {
        case .create:
            let created = try await networkService.createListing(dto)
            try await markSynced(listingId: change.listingId, with: created)
        case .update, .toggleFavorite:
            let updated = try await networkService.updateListing(dto)
            try await markSynced(listingId: change.listingId, with: updated)
        }
    }

    /// Transitions a listing to `.syncing` so the UI can show an
    /// in-progress badge before the actual network call.
    private func markSyncing(listingId: String) async {
        let context = persistence.backgroundContext
        await context.perform {
            let request: NSFetchRequest<ListingEntity> = ListingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listingId)
            guard let entity = try? context.fetch(request).first else { return }
            entity.syncState = SyncState.syncing.rawValue
            try? context.save()
        }
    }

    private func markSynced(listingId: String, with dto: ListingDTO) async throws {
        let context = persistence.backgroundContext
        try await context.perform {
            let request: NSFetchRequest<ListingEntity> = ListingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", listingId)
            guard let entity = try? context.fetch(request).first else { return }
            let remote = dto.toDomain(localImagePath: entity.localImagePath, syncState: .synced)
            entity.apply(remote)
            try context.save()
        }
    }

    private func fetchPendingChanges() async -> [PendingChange] {
        let context = persistence.backgroundContext
        return await context.perform {
            let request: NSFetchRequest<PendingChangeEntity> = PendingChangeEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            let entities = (try? context.fetch(request)) ?? []
            return entities.map { $0.toDomain() }
        }
    }

    private func remove(_ change: PendingChange) async {
        let context = persistence.backgroundContext
        await context.perform {
            let request: NSFetchRequest<PendingChangeEntity> = PendingChangeEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", change.id)
            guard let entity = try? context.fetch(request).first else { return }
            context.delete(entity)
            try? context.save()
        }
    }

    private func recordFailure(_ change: PendingChange, error: Error) async {
        let context = persistence.backgroundContext
        await context.perform {
            let request: NSFetchRequest<PendingChangeEntity> = PendingChangeEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", change.id)
            guard let entity = try? context.fetch(request).first else { return }
            entity.retryCount += 1
            entity.lastError = error.localizedDescription
            try? context.save()
        }
    }

    private func updateStatus(state: SyncStatus.State, pendingCount: Int? = nil, lastSyncedAt: Date? = nil) {
        let current = statusSubject.value
        statusSubject.send(SyncStatus(
            state: state,
            pendingCount: pendingCount ?? current.pendingCount,
            lastSyncedAt: lastSyncedAt ?? current.lastSyncedAt
        ))
    }
}


