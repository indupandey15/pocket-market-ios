//
//  ListingRepositoryProtocol.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  The single boundary the Presentation layer talks to. Everything below this
//  (Core Data, networking, sync) is an implementation detail the ViewModel
//  never needs to know about — this is what makes the ViewModel unit-testable
//  with a fake, and what "clear separation of layers" means in practice.
//

import Foundation
import Combine

protocol ListingRepositoryProtocol {
    /// Publishes the current local snapshot of listings; updates whenever
    /// Core Data changes (remote fetch, favorite toggle, offline create, sync).
    var listingsPublisher: AnyPublisher<[Listing], Never> { get }

    /// Publishes current sync status (idle / syncing / last error) for the UI badge.
    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> { get }

    /// Loads from local DB immediately, then refreshes from remote in the background.
    func loadListings() async

    /// Force a remote refresh (pull-to-refresh).
    func refresh() async throws

    func toggleFavorite(listingId: String) async

    /// Creates a listing locally immediately (optimistic), queues it for sync.
    func createListing(_ draft: NewListingDraft) async throws

    /// Attempts to drain the pending-change queue against the remote API.
    func syncPendingChanges() async
}

struct SyncStatus: Equatable {
    enum State: Equatable { case idle, syncing, offline, error(String) }
    var state: State
    var pendingCount: Int
    var lastSyncedAt: Date?
}

/// Input for creating a listing — kept separate from `Listing` because the
/// user hasn't picked an id/version/timestamps yet; the repository assigns those.
struct NewListingDraft {
    var title: String
    var description: String
    var price: Double
    var category: String
    var condition: ListingCondition
    var localImagePath: String?
}

