//
//  BundledJSONNetworkService.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Stand-in "remote API" for the take-home: reads listings_200.json from the
//  app bundle and simulates real network latency + occasional failure, so
//  the loading/error/retry paths in the UI are genuinely exercised rather
//  than always succeeding instantly. This is what the assignment means by
//  "mock REST endpoint" when there's no server to stand up in 5-6 hours.
//
//  Swap `AppContainer.networkService` to `NetworkService()` to point at a
//  real json-server / Gist-hosted endpoint instead — nothing else changes,
//  because both conform to NetworkServiceProtocol.
//

import Foundation

final class BundledJSONNetworkService: NetworkServiceProtocol {
    private let simulatedLatencyNanoseconds: UInt64
    private let failureRate: Double

    init(simulatedLatencyNanoseconds: UInt64 = 500_000_000, failureRate: Double = 0.0) {
        self.simulatedLatencyNanoseconds = simulatedLatencyNanoseconds
        self.failureRate = failureRate
    }

    func fetchListings() async throws -> [ListingDTO] {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        if Double.random(in: 0...1) < failureRate {
            throw NetworkError.server(503)
        }
        guard let url = Bundle.main.url(forResource: "listings_200", withExtension: "json") else {
            throw NetworkError.invalidResponse
        }
        let data = try Data(contentsOf: url)
        do {
            let decoded = try JSONDecoder().decode(ListingsResponseDTO.self, from: data)
            return decoded.listings
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }
    }

    func createListing(_ dto: ListingDTO) async throws -> ListingDTO {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        if Double.random(in: 0...1) < failureRate { throw NetworkError.server(500) }
        return dto
    }

    func updateListing(_ dto: ListingDTO) async throws -> ListingDTO {
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        if Double.random(in: 0...1) < failureRate { throw NetworkError.server(500) }
        let updated = ListingDTO(
            id: dto.id, title: dto.title, description: dto.description, price: dto.price,
            currency: dto.currency, category: dto.category, condition: dto.condition,
            imageURL: dto.imageURL, thumbnailURL: dto.thumbnailURL, sellerId: dto.sellerId,
            location: dto.location, createdAt: dto.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date()), isFavorite: dto.isFavorite,
            version: dto.version + 1
        )
        return updated
    }
}


