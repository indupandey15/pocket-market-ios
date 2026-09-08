//
//  NetworkService.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Thin wrapper over URLSession. Points at MockAPIEndpoints — swap that
//  struct's baseURL to move from the mock JSON server to a real backend
//  without touching any other layer.
//

import Foundation

final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let endpoints: MockAPIEndpoints

    init(session: URLSession = .shared, endpoints: MockAPIEndpoints = .init()) {
        self.session = session
        self.endpoints = endpoints
    }

    func fetchListings() async throws -> [ListingDTO] {
        let (data, response) = try await session.data(from: endpoints.listingsURL)
        try Self.validate(response)
        do {
            let decoded = try JSONDecoder().decode(ListingsResponseDTO.self, from: data)
            return decoded.listings
        } catch {
            throw NetworkError.decodingFailed(String(describing: error))
        }
    }

    func createListing(_ dto: ListingDTO) async throws -> ListingDTO {
        // Mock endpoint: in a real backend this POSTs and returns the
        // server-assigned record. Here we simulate network latency and
        // echo the payload back with an incremented version, which is
        // enough to exercise the sync + conflict-resolution paths.
        try await Task.sleep(nanoseconds: 400_000_000)
        let created = ListingDTO(
            id: dto.id, title: dto.title, description: dto.description, price: dto.price,
            currency: dto.currency, category: dto.category, condition: dto.condition,
            imageURL: dto.imageURL, thumbnailURL: dto.thumbnailURL, sellerId: dto.sellerId,
            location: dto.location, createdAt: dto.createdAt, updatedAt: ISO8601DateFormatter().string(from: Date()),
            isFavorite: dto.isFavorite, version: dto.version
        )
        return created
    }

    func updateListing(_ dto: ListingDTO) async throws -> ListingDTO {
        try await Task.sleep(nanoseconds: 300_000_000)
        return ListingDTO(
            id: dto.id, title: dto.title, description: dto.description, price: dto.price,
            currency: dto.currency, category: dto.category, condition: dto.condition,
            imageURL: dto.imageURL, thumbnailURL: dto.thumbnailURL, sellerId: dto.sellerId,
            location: dto.location, createdAt: dto.createdAt, updatedAt: ISO8601DateFormatter().string(from: Date()),
            isFavorite: dto.isFavorite, version: dto.version + 1
        )
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw NetworkError.server(http.statusCode) }
    }
}

/// Centralizes every URL the app talks to. `listingsURL` defaults to the
/// bundled listings_200.json served via a local file URL for the take-home
/// demo — point it at a real json-server/Gist URL to demo genuine HTTP.
struct MockAPIEndpoints {
    var baseURL: URL

    var listingsURL: URL { baseURL.appendingPathComponent("listings") }
    var syncURL: URL { baseURL.appendingPathComponent("sync") }

    init(baseURL: URL = URL(string: "https://example-mock-api.local/api/v1/")!) {
        self.baseURL = baseURL
    }
}


