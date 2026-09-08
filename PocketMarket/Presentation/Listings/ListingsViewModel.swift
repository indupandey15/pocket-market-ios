//
//  ListingsViewModel.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Talks only to ListingRepositoryProtocol — knows nothing about Core Data,
//  networking, or sync internals. That boundary is what makes this class
//  testable with a fake repository (see ListingRepositoryTests.swift).
//

import Foundation
import Combine

@MainActor
final class ListingsViewModel: ObservableObject {
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var syncStatus = SyncStatus(state: .idle, pendingCount: 0, lastSyncedAt: nil)
    @Published var selectedCategory: String? = nil
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let repository: ListingRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    var filteredListings: [Listing] {
        guard let category = selectedCategory else { return listings }
        return listings.filter { $0.category == category }
    }

    var categories: [String] {
        Array(Set(listings.map(\.category))).sorted()
    }

    init(repository: ListingRepositoryProtocol) {
        self.repository = repository

        repository.listingsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$listings)

        repository.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncStatus)
    }

    func onAppear() {
        Task { await repository.loadListings() }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await repository.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite(_ listing: Listing) {
        Task { await repository.toggleFavorite(listingId: listing.id) }
    }

    /// Called from `onAppear` on a grid cell — a natural hook point for
    /// prefetching/pagination if the catalog grew beyond 200 items; kept
    /// as a no-op here since 200 items load comfortably in one page, but
    /// documented so the "smart resource usage" trade-off is explicit.
    func prefetchIfNeeded(currentItem: Listing) {
        // Intentionally a no-op for the 200-item scope of this assignment.
        // See README "Scaling beyond 200 items" for the pagination plan.
    }
}


