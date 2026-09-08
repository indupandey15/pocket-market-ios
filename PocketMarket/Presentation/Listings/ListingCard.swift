//
//  ListingCard.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//
import SwiftUI

struct ListingCard: View {
    let listing: Listing
    let onFavoriteTap: () -> Void

    private static let cellImageSize = CGSize(width: 170, height: 170)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImageView(
                    url: listing.thumbnailURL ?? listing.imageURL,
                    localImagePath: listing.localImagePath,
                    targetSize: Self.cellImageSize
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: onFavoriteTap) {
                    Image(systemName: listing.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(listing.isFavorite ? .red : .white)
                        .padding(8)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .padding(6)

                if listing.syncState != .synced {
                    SyncStatusBadge(state: listing.syncState)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }

            Text(listing.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Text(listing.displayPrice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

