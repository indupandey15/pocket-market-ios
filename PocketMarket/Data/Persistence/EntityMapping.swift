//
//  EntityMapping.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  ListingEntity / PendingChangeEntity are Xcode-codegen'd NSManagedObject
//  subclasses (see OfflineMarketplace.xcdatamodeld, codeGenerationType=class).
//  These extensions are the ONLY place Core Data types get translated to/from
//  domain types — nothing above the Repository ever imports CoreData.
//

import CoreData
import Foundation

extension ListingEntity {
    func toDomain() -> Listing {
        Listing(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            description: listingDescription ?? "",
            price: price,
            currency: currency ?? "CAD",
            category: category ?? "",
            condition: ListingCondition(rawValue: condition ?? "good") ?? .good,
            imageURL: (imageURL?.isEmpty == false) ? URL(string: imageURL!) : nil,
            thumbnailURL: (thumbnailURL?.isEmpty == false) ? URL(string: thumbnailURL!) : nil,
            localImagePath: localImagePath,
            sellerId: sellerId ?? "",
            location: location ?? "",
            createdAt: createdAt ?? .distantPast,
            updatedAt: updatedAt ?? .distantPast,
            isFavorite: isFavorite,
            version: Int(version),
            syncState: SyncState(rawValue: syncState ?? "synced") ?? .synced
        )
    }

    /// Applies a domain model's fields onto this managed object. Caller is
    /// responsible for the save; this stays a pure field-copy so it can be
    /// reused for both "insert new" and "update existing" paths.
    func apply(_ listing: Listing) {
        id = listing.id
        title = listing.title
        listingDescription = listing.description
        price = listing.price
        currency = listing.currency
        category = listing.category
        condition = listing.condition.rawValue
        imageURL = listing.imageURL?.absoluteString
        thumbnailURL = listing.thumbnailURL?.absoluteString
        localImagePath = listing.localImagePath
        sellerId = listing.sellerId
        location = listing.location
        createdAt = listing.createdAt
        updatedAt = listing.updatedAt
        isFavorite = listing.isFavorite
        version = Int32(listing.version)
        syncState = listing.syncState.rawValue
    }
}

extension PendingChangeEntity {
    func toDomain() -> PendingChange {
        PendingChange(
            id: id ?? UUID().uuidString,
            listingId: listingId ?? "",
            operation: PendingOperation(rawValue: operation ?? "update") ?? .update,
            payload: payload ?? Data(),
            localImagePath: localImagePath,
            createdAt: createdAt ?? Date(),
            retryCount: Int(retryCount),
            lastError: lastError
        )
    }
}


