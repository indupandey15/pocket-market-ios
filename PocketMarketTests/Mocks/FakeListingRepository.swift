//
//  FakeListingRepository.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  In-memory stand-in for ListingRepositoryProtocol. Because the ViewModel
//  layer only depends on the protocol (not on ListingRepository/Core Data
//  directly), tests never need a real persistent store — this is the payoff
//  of the repository boundary described in ARCHITECTURE.md.
//

import Foundation
import Combine
@testable import PocketMarket

final class FakeListingRepository: ListingRepositoryProtocol {
    private let listingsSubject = CurrentValueSubject<[Listing], Never>([])
    private let statusSubject = CurrentValueSubject<SyncStatus, Never>(
        SyncStatus(state: .idle, pendingCount: 0, lastSyncedAt: nil)
    )

    var listingsPublisher: AnyPublisher<[Listing], Never> { listingsSubject.eraseToAnyPublisher() }
    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> { statusSubject.eraseToAnyPublisher() }

    private(set) var createdDrafts: [NewListingDraft] = []
    private(set) var favoritedIds: [String] = []
    var seedListings: [Listing] = [] { didSet { listingsSubject.send(seedListings) } }
    var shouldThrowOnCreate = false

    func loadListings() async {
        listingsSubject.send(seedListings)
    }

    func refresh() async throws {}

    func toggleFavorite(listingId: String) async {
        favoritedIds.append(listingId)
    }

    func createListing(_ draft: NewListingDraft) async throws {
        if shouldThrowOnCreate {
            throw NetworkError.offline
        }
        createdDrafts.append(draft)
    }

    func syncPendingChanges() async {}
}


