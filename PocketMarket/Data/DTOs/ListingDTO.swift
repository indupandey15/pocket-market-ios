//
//  ListingDTO.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Wire format — mirrors listings_200.json exactly. Never exposed above the
//  Repository; everything else works with the `Listing` domain model.
//

import Foundation

struct ListingsResponseDTO: Codable {
    let meta: MetaDTO
    let listings: [ListingDTO]
}

struct MetaDTO: Codable {
    let count: Int
    let generatedAt: String
    let source: String
}

struct ListingDTO: Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let currency: String
    let category: String
    let condition: String
    let imageURL: String
    let thumbnailURL: String
    let sellerId: String
    let location: String
    let createdAt: String
    let updatedAt: String
    let isFavorite: Bool
    let version: Int
}

// MARK: - DTO <-> Domain mapping

extension ListingDTO {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Defensive mapping: a malformed date, empty image URL, or unknown
    /// condition string should degrade gracefully rather than crash the
    /// whole feed — this matters at 200 items where one bad record
    /// shouldn't take the rest down with it.
    func toDomain(localImagePath: String? = nil, syncState: SyncState = .synced) -> Listing {
        let created = Self.isoFormatter.date(from: createdAt) ?? Date.distantPast
        let updated = Self.isoFormatter.date(from: updatedAt) ?? created

        return Listing(
            id: id,
            title: title,
            description: description,
            price: price,
            currency: currency,
            category: category,
            condition: ListingCondition(rawValue: condition) ?? .good,
            imageURL: imageURL.isEmpty ? nil : URL(string: imageURL),
            thumbnailURL: thumbnailURL.isEmpty ? nil : URL(string: thumbnailURL),
            localImagePath: localImagePath,
            sellerId: sellerId,
            location: location,
            createdAt: created,
            updatedAt: updated,
            isFavorite: isFavorite,
            version: version,
            syncState: syncState
        )
    }
}

extension Listing {
    func toDTO() -> ListingDTO {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return ListingDTO(
            id: id,
            title: title,
            description: description,
            price: price,
            currency: currency,
            category: category,
            condition: condition.rawValue,
            imageURL: imageURL?.absoluteString ?? "",
            thumbnailURL: thumbnailURL?.absoluteString ?? "",
            sellerId: sellerId,
            location: location,
            createdAt: formatter.string(from: createdAt),
            updatedAt: formatter.string(from: updatedAt),
            isFavorite: isFavorite,
            version: version
        )
    }
}


