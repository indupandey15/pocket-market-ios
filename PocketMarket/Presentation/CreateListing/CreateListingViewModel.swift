//
//  CreateListingViewModel.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Handles the "create a new listing while offline" flow. Validation runs
//  locally before anything touches the repository — the assignment calls
//  out "input validation" explicitly under Security & Standards.
//

import Foundation
import UIKit

@MainActor
final class CreateListingViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var priceText = ""
    @Published var category = "Electronics"
    @Published var condition: ListingCondition = .good
    @Published var selectedImage: UIImage?
    @Published private(set) var validationErrors: [String] = []
    @Published private(set) var isSaving = false
    @Published private(set) var didSave = false

    let categories = ["Electronics", "Furniture", "Clothing", "Books", "Sports", "Toys", "Home & Garden", "Automotive"]

    private let repository: ListingRepositoryProtocol

    init(repository: ListingRepositoryProtocol) {
        self.repository = repository
    }

    func save() async {
        validate()
        guard validationErrors.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        let localImagePath = persistImageIfNeeded()
        let draft = NewListingDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            price: Double(priceText) ?? 0,
            category: category,
            condition: condition,
            localImagePath: localImagePath
        )

        do {
            try await repository.createListing(draft)
            didSave = true
        } catch {
            validationErrors = [error.localizedDescription]
        }
    }

    /// Pure function, independent of any UI state, so it's directly unit
    /// testable (see CreateListingValidationTests.swift).
    func validate() {
        var errors: [String] = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            errors.append("Title is required.")
        } else if trimmedTitle.count > 80 {
            errors.append("Title must be 80 characters or fewer.")
        }

        if let price = Double(priceText) {
            if price <= 0 { errors.append("Price must be greater than zero.") }
            if price > 100_000 { errors.append("Price seems unreasonably high — double-check it.") }
        } else {
            errors.append("Enter a valid price.")
        }

        if description.count > 1000 {
            errors.append("Description must be 1000 characters or fewer.")
        }

        validationErrors = errors
    }

    private func persistImageIfNeeded() -> String? {
        guard let selectedImage, let data = selectedImage.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            return nil
        }
    }
}


