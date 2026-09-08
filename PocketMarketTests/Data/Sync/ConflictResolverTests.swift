//
//  ConflictResolverTests.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//
import XCTest
@testable import PocketMarket

final class ConflictResolverTests: XCTestCase {

    private func makeListing(version: Int, updatedAt: Date, title: String) -> Listing {
        Listing(
            id: "1", title: title, description: "", price: 10, currency: "CAD",
            category: "Electronics", condition: .good, imageURL: nil, thumbnailURL: nil,
            localImagePath: nil, sellerId: "s1", location: "Toronto",
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: updatedAt,
            isFavorite: false, version: version, syncState: .synced
        )
    }

    func test_higherVersionWins_regardlessOfTimestamp() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)

        // Local has a lower version but a *newer* timestamp — version should
        // still take precedence, since it's the authoritative monotonic counter.
        let local = makeListing(version: 1, updatedAt: newer, title: "Local Edit")
        let remote = makeListing(version: 2, updatedAt: older, title: "Remote Edit")

        let resolved = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolved.title, "Remote Edit")
    }

    func test_equalVersions_fallsBackToMostRecentTimestamp() {
        let local = makeListing(version: 3, updatedAt: Date(timeIntervalSince1970: 500), title: "Local Edit")
        let remote = makeListing(version: 3, updatedAt: Date(timeIntervalSince1970: 100), title: "Remote Edit")

        let resolved = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolved.title, "Local Edit")
    }

    func test_identicalVersionsAndTimestamps_prefersRemoteAsSourceOfTruth() {
        let sameDate = Date(timeIntervalSince1970: 300)
        let local = makeListing(version: 5, updatedAt: sameDate, title: "Local Edit")
        let remote = makeListing(version: 5, updatedAt: sameDate, title: "Remote Edit")

        let resolved = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolved.title, "Remote Edit")
    }
}

