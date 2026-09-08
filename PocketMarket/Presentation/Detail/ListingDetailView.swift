//
//  ListingDetailView.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
import SwiftUI

struct ListingDetailView: View {
    let listing: Listing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CachedAsyncImageView(
                    url: listing.imageURL ?? listing.thumbnailURL,
                    localImagePath: listing.localImagePath,
                    targetSize: CGSize(width: 400, height: 400)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(listing.title).font(.title2.bold())
                Text(listing.displayPrice).font(.title3).foregroundStyle(.secondary)

                HStack {
                    Label(listing.location, systemImage: "mappin.and.ellipse")
                    Spacer()
                    Label(listing.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                          systemImage: "tag")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if !listing.description.isEmpty {
                    Text(listing.description).font(.body)
                }

                if listing.syncState != .synced {
                    SyncStatusBadge(state: listing.syncState)
                }
            }
            .padding()
        }
        .navigationTitle(listing.category)
        .navigationBarTitleDisplayMode(.inline)
    }
}

