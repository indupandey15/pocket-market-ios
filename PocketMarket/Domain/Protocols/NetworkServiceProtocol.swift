//
//  NetworkServiceProtocol.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
import Foundation

protocol NetworkServiceProtocol {
    func fetchListings() async throws -> [ListingDTO]
    /// Simulated "create" endpoint — returns the server-assigned copy
    /// (in a real API this is where id collisions / server validation happen).
    func createListing(_ dto: ListingDTO) async throws -> ListingDTO
    func updateListing(_ dto: ListingDTO) async throws -> ListingDTO
}

enum NetworkError: Error, LocalizedError {
    case offline
    case invalidResponse
    case decodingFailed(String)
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .offline: return "No network connection."
        case .invalidResponse: return "Received an invalid response from the server."
        case .decodingFailed(let detail): return "Failed to decode response: \(detail)"
        case .server(let code): return "Server returned status \(code)."
        }
    }
}


