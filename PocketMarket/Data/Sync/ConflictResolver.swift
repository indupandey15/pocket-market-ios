//
//  ConflictResolver.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Isolated on purpose: this is pure logic with no Core Data or networking
//  dependency, so it's the easiest and most valuable thing in the app to
//  unit test (see PocketMarketTests/ConflictResolverTests.swift).
//

import Foundation

enum ConflictResolver {
    /// Last-write-wins keyed on `version` first (authoritative, monotonic),
    /// falling back to `updatedAt` if versions are equal (e.g. two
    /// independent offline edits before either has synced). Ties after both
    /// checks favor the server copy, since the server is the shared source
    /// of truth once reachable.
    static func resolve(local: Listing, remote: Listing) -> Listing {
        if local.version != remote.version {
            return local.version > remote.version ? local : remote
        }
        if local.updatedAt != remote.updatedAt {
            return local.updatedAt > remote.updatedAt ? local : remote
        }
        return remote
    }
}


