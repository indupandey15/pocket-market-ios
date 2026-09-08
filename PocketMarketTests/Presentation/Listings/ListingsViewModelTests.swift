//
//  ListingsViewModelTests.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//
import XCTest
import Combine
@testable import PocketMarket

@MainActor
final class ListingsViewModelTests: XCTestCase {

    private func makeListing(id: String, category: String) -> Listing {
        Listing(
            id: id, title: "Item \(id)", description: "", price: 10, currency: "CAD",
            category: category, condition: .good, imageURL: nil, thumbnailURL: nil,
            localImagePath: nil, sellerId: "s1", location: "Toronto",
            createdAt: Date(), updatedAt: Date(), isFavorite: false, version: 1, syncState: .synced
        )
    }

    /// Wait for the Combine pipeline (`.receive(on: DispatchQueue.main)`) to
    /// deliver seeded listings to the ViewModel's `@Published` property.
    private func awaitListings(
        _ viewModel: ListingsViewModel,
        count: Int,
        timeout: TimeInterval = 2.0
    ) async throws {
        let start = Date()
        while viewModel.listings.count < count {
            guard Date().timeIntervalSince(start) < timeout else {
                XCTFail("Timed out waiting for \(count) listings (got \(viewModel.listings.count))")
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    func test_filteredListings_returnsAllWhenNoCategorySelected() async throws {
        let fake = FakeListingRepository()
        fake.seedListings = [
            makeListing(id: "1", category: "Electronics"),
            makeListing(id: "2", category: "Books")
        ]
        let viewModel = ListingsViewModel(repository: fake)
        viewModel.onAppear()

        try await awaitListings(viewModel, count: 2)

        XCTAssertEqual(viewModel.filteredListings.count, 2)
    }

    func test_filteredListings_filtersBySelectedCategory() async throws {
        let fake = FakeListingRepository()
        fake.seedListings = [
            makeListing(id: "1", category: "Electronics"),
            makeListing(id: "2", category: "Books"),
            makeListing(id: "3", category: "Electronics")
        ]
        let viewModel = ListingsViewModel(repository: fake)
        viewModel.onAppear()

        try await awaitListings(viewModel, count: 3)

        viewModel.selectedCategory = "Electronics"

        XCTAssertEqual(viewModel.filteredListings.count, 2)
        XCTAssertTrue(viewModel.filteredListings.allSatisfy { $0.category == "Electronics" })
    }

    func test_toggleFavorite_forwardsToRepository() {
        let fake = FakeListingRepository()
        let listing = makeListing(id: "42", category: "Toys")
        fake.seedListings = [listing]
        let viewModel = ListingsViewModel(repository: fake)
        viewModel.onAppear()

        viewModel.toggleFavorite(listing)

        let expectation = expectation(description: "favorite forwarded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(fake.favoritedIds, ["42"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
