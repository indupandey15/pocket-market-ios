//
//  Listing.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Domain model — pure Swift, no persistence or networking knowledge.
//  This is what the ViewModel/View layer works with.
//

import Foundation

enum ListingCondition: String, Codable, CaseIterable, Hashable {
    case new, likeNew = "like_new", good, fair
}

enum SyncState: String, Codable, Hashable {
    case synced        // matches server, no pending work
    case pendingCreate // created offline, not yet uploaded
    case pendingUpdate // edited offline (e.g. favorited), not yet uploaded
    case syncing       // upload in flight
    case failed        // last sync attempt failed, will retry
}

struct Listing: Identifiable, Equatable, Hashable {
    let id: String
    var title: String
    var description: String
    var price: Double
    var currency: String
    var category: String
    var condition: ListingCondition
    var imageURL: URL?
    var thumbnailURL: URL?
    /// Local file path for an image attached while offline (camera/photo picker),
    /// used before the image has been uploaded and given a remote URL.
    var localImagePath: String?
    var sellerId: String
    var location: String
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    /// Monotonic version used for last-write-wins conflict resolution.
    var version: Int
    var syncState: SyncState

    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency) \(price)"
    }
}


