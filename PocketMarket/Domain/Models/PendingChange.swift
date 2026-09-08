//
//  PendingChange.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Represents one queued offline mutation. The SyncEngine drains a table of
//  these (oldest-first) whenever connectivity returns.
//

import Foundation

enum PendingOperation: String, Codable, Equatable {
    case create
    case update
    case toggleFavorite
}

struct PendingChange: Identifiable, Equatable {
    let id: String                 // UUID for the change itself
    let listingId: String          // which listing this affects
    let operation: PendingOperation
    /// JSON-encoded snapshot of the listing fields needed to replay this change.
    let payload: Data
    let localImagePath: String?    // image to upload alongside a create/update, if any
    let createdAt: Date
    var retryCount: Int
    var lastError: String?
}


