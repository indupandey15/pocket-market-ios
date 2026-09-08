//
//  AppContainer.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Deliberately simple constructor-injection container rather than a
//  framework — appropriate for this app's size, and every dependency here
//  is a protocol, so any of it can be swapped for a fake in tests or
//  SwiftUI previews.
//

import Foundation

@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let persistence: PersistenceController
    let networkService: NetworkServiceProtocol
    let syncEngine: SyncEngine
    let listingRepository: ListingRepositoryProtocol
    let imageCache: ImageCacheServiceProtocol
    let keychain: KeychainServiceProtocol

    private init() {
        persistence = .shared
        // Swap for NetworkService() to point at a real hosted mock API.
        networkService = BundledJSONNetworkService(simulatedLatencyNanoseconds: 500_000_000, failureRate: 0.0)
        syncEngine = SyncEngine(persistence: persistence, networkService: networkService)
        listingRepository = ListingRepository(persistence: persistence, networkService: networkService, syncEngine: syncEngine)
        imageCache = ImageCacheService.shared
        keychain = KeychainService()
    }

    func makeListingsViewModel() -> ListingsViewModel {
        ListingsViewModel(repository: listingRepository)
    }

    func makeCreateListingViewModel() -> CreateListingViewModel {
        CreateListingViewModel(repository: listingRepository)
    }
}
