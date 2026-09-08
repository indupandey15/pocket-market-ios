//
//  ImageCacheService.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Why this exists: SwiftUI's AsyncImage decodes full-resolution images and
//  keeps no cross-view cache, so a 200-item grid re-downloads and re-decodes
//  on every scroll pass — memory spikes and scrolling stutters. This service
//  fixes both problems:
//
//   1. Memory cache (NSCache) — automatically evicted under memory pressure,
//      capped by both count and byte size so it can't grow unbounded.
//   2. Disk cache — survives app relaunch, avoids re-downloading 200 images
//      every cold start.
//   3. Downsampling at decode time (ImageIO, not UIGraphicsImageRenderer) —
//      an image is decoded directly at the target pixel size instead of
//      full-res-then-scaled, which is the single biggest lever for keeping
//      memory flat as the grid grows.
//

import UIKit
import CryptoKit

protocol ImageCacheServiceProtocol {
    /// Returns a downsampled image sized for `targetSize` (in points, at the
    /// screen's scale), fetching + caching it if necessary.
    func image(for url: URL, targetSize: CGSize) async -> UIImage?
    func cancelLoad(for url: URL) async
}

actor ImageCacheService: ImageCacheServiceProtocol {
    
    static let shared = ImageCacheService()

    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150                 // ~ enough for a couple of screens of grid cells
        cache.totalCostLimit = 60 * 1024 * 1024 // ~60MB ceiling; NSCache also responds to system memory pressure
        return cache
    }()

    private let diskCacheURL: URL
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func image(for url: URL, targetSize: CGSize) async -> UIImage? {
        let key = cacheKey(url: url, size: targetSize)

        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Coalesce concurrent requests for the same image+size (common when a
        // cell scrolls on/off/on screen quickly) so we don't fire duplicate
        // downloads or duplicate decode work.
        if let existing = inFlightTasks[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            await self?.loadAndCache(url: url, targetSize: targetSize, key: key)
        }
        inFlightTasks[key] = task
        let result = await task.value
        inFlightTasks[key] = nil
        return result
    }

    func cancelLoad(for url: URL) async {
        // Best-effort: cancel any in-flight tasks whose key is derived from
        // this URL, regardless of requested size (cell was reused/scrolled away).
        for (key, task) in inFlightTasks where key.hasPrefix(url.absoluteString) {
            task.cancel()
            inFlightTasks[key] = nil
        }
    }

    // MARK: - Private

    private func loadAndCache(url: URL, targetSize: CGSize, key: String) async -> UIImage? {
        if Task.isCancelled { return nil }

        if let diskImage = readFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString, cost: diskImage.estimatedByteCost)
            return diskImage
        }

        guard let data = try? Data(contentsOf: url) else { return nil } // NB: see README for URLSession-based prod version
        if Task.isCancelled { return nil }

        guard let downsampled = Self.downsample(data: data, to: targetSize) else { return nil }
        memoryCache.setObject(downsampled, forKey: key as NSString, cost: downsampled.estimatedByteCost)
        writeToDisk(image: downsampled, key: key)
        return downsampled
    }

    /// Decodes the image directly at `targetSize` using ImageIO's thumbnail
    /// generator, so a 4000x4000 source photo never gets fully decoded into
    /// memory just to be shown in a 160x160 grid cell.
    private static func downsample(data: Data, to targetSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * scale
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private func cacheKey(url: URL, size: CGSize) -> String {
        "\(url.absoluteString)|\(Int(size.width))x\(Int(size.height))"
    }

    private func diskPath(for key: String) -> URL {
        let hashed = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appendingPathComponent(hashed).appendingPathExtension("jpg")
    }

    private func readFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func writeToDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }
        try? data.write(to: diskPath(for: key), options: .atomic)
    }

    /// Disk cache eviction is deliberately simple for a 5-6hr scope: sweep on
    /// launch and drop the oldest files past a count cap. A production
    /// version would track last-access time and use a proper LRU + a real
    /// size budget (see README "Trade-offs").
    func evictDiskCacheIfNeeded(maxFiles: Int = 500) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        guard files.count > maxFiles else { return }

        let sorted = files.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return d0 < d1
        }
        for file in sorted.prefix(files.count - maxFiles) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

private extension UIImage {
    /// Rough byte cost so NSCache's totalCostLimit reflects actual memory use.
    var estimatedByteCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}


