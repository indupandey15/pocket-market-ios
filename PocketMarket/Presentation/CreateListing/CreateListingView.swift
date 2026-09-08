//
//  CreateListingView.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//
import SwiftUI

struct CreateListingView: View {
    @ObservedObject var viewModel: CreateListingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingImageSource = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    imagePickerSection
                }

                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Price (CAD)", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(viewModel.categories, id: \.self) { Text($0) }
                    }
                    Picker("Condition", selection: $viewModel.condition) {
                        ForEach(ListingCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(condition)
                        }
                    }
                }

                if !viewModel.validationErrors.isEmpty {
                    Section {
                        ForEach(viewModel.validationErrors, id: \.self) { error in
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await viewModel.save()
                            if viewModel.didSave { dismiss() }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingImageSource) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView(image: $viewModel.selectedImage)
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoLibraryPickerView(image: $viewModel.selectedImage)
            }
        }
    }

    private var imagePickerSection: some View {
        Button {
            showingImageSource = true
        } label: {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Add a photo")
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}


