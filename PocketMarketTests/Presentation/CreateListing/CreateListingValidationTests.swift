//
//  CreateListingValidationTests.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//
import XCTest
@testable import PocketMarket

@MainActor
final class CreateListingValidationTests: XCTestCase {
    private var viewModel: CreateListingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = CreateListingViewModel(repository: FakeListingRepository())
    }

    func test_emptyTitle_producesValidationError() {
        viewModel.title = ""
        viewModel.priceText = "10"
        viewModel.validate()
        XCTAssertTrue(viewModel.validationErrors.contains("Title is required."))
    }

    func test_nonNumericPrice_producesValidationError() {
        viewModel.title = "Desk Lamp"
        viewModel.priceText = "not-a-number"
        viewModel.validate()
        XCTAssertTrue(viewModel.validationErrors.contains("Enter a valid price."))
    }

    func test_zeroOrNegativePrice_producesValidationError() {
        viewModel.title = "Desk Lamp"
        viewModel.priceText = "0"
        viewModel.validate()
        XCTAssertTrue(viewModel.validationErrors.contains("Price must be greater than zero."))
    }

    func test_validInput_producesNoErrors() {
        viewModel.title = "Desk Lamp"
        viewModel.priceText = "24.99"
        viewModel.description = "A lightly used desk lamp."
        viewModel.validate()
        XCTAssertTrue(viewModel.validationErrors.isEmpty)
    }
}

