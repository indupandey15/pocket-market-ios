//
//  CachedAsyncImageView.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Replaces SwiftUI's AsyncImage for grid usage. Two differences that matter
//  at 200+ items:
//   1. Goes through ImageCacheService (memory+disk+downsample) instead of
//      decoding full-res images with no cross-cell cache.
//   2. Cancels its load in onDisappear, so flinging through the grid doesn't
//      leave 100+ orphaned decode tasks running for cells that scrolled away.
//

import SwiftUI

struct CachedAsyncImageView: View {
    let url: URL?
    /// Optional local file name (in Documents) for images attached offline.
    let localImagePath: String?
    let targetSize: CGSize

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    init(url: URL?, localImagePath: String? = nil, targetSize: CGSize) {
        self.url = url
        self.localImagePath = localImagePath
        self.targetSize = targetSize
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if url == nil && localImagePath == nil {
                // No image source at all — show a static placeholder, not a spinner.
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    )
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .frame(width: targetSize.width, height: targetSize.height)
        .clipped()
        .task(id: url?.absoluteString ?? localImagePath ?? "") {
            await load()
        }
        .onDisappear {
            loadTask?.cancel()
            if let url { Task { await ImageCacheService.shared.cancelLoad(for: url) } }
        }
    }

    private func load() async {
        // 1. Try loading from the local Documents directory first (offline-created listings).
        if let localImagePath, !localImagePath.isEmpty {
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(localImagePath)
            if let data = try? Data(contentsOf: docsURL),
               let localImage = UIImage(data: data) {
                if !Task.isCancelled { image = localImage }
                return
            }
        }

        // 2. Fall back to remote URL via the cache service.
        guard let url else { image = nil; return }
        image = nil
        let result = await ImageCacheService.shared.image(for: url, targetSize: targetSize)
        if !Task.isCancelled {
            image = result
        }
    }
}


