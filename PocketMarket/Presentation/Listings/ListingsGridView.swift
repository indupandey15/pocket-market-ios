//
//  ListingsGridView.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  LazyVGrid, as requested — cells only materialize (and only trigger their
//  CachedAsyncImageView load) as they scroll into view, which combined with
//  ImageCacheService's downsampling is what keeps 200+ items smooth.
//

import SwiftUI

struct ListingsGridView: View {
    @StateObject var viewModel: ListingsViewModel
    @State private var showingCreateSheet = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredListings) { listing in
                        NavigationLink(value: listing) {
                            ListingCard(listing: listing) {
                                viewModel.toggleFavorite(listing)
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear { viewModel.prefetchIfNeeded(currentItem: listing) }
                    }
                }
                .padding(12)
            }
            .navigationTitle("Marketplace")
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing)
            }
            .safeAreaInset(edge: .top) {
                GlobalSyncStatusView(status: viewModel.syncStatus)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingCreateSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    categoryMenu
                }
            }
            .refreshable { await viewModel.refresh() }
            .sheet(isPresented: $showingCreateSheet) {
                CreateListingView(viewModel: AppContainer.shared.makeCreateListingViewModel())
            }
            .onAppear { viewModel.onAppear() }
        }
    }

    private var categoryMenu: some View {
        Menu {
            Button("All") { viewModel.selectedCategory = nil }
            ForEach(viewModel.categories, id: \.self) { category in
                Button(category) { viewModel.selectedCategory = category }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}


