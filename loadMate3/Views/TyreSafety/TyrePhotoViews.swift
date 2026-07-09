import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct TyrePhotoGallerySection: View {
    @Environment(\.modelContext) private var modelContext

    let vehicleID: UUID
    let record: TyreRecord
    var inspection: TyreInspection?
    var caption: String = "Photograph the tyre for your own records. Photos are stored on this device."
    var onAnalyzeSidewall: ((TyrePhoto) -> Void)?

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var selectedKind: TyrePhotoKind = .general
    @State private var showKindPicker = false
    @State private var pendingImage: UIImage?
    @State private var viewerPhoto: TyrePhoto?

    private var displayedPhotos: [TyrePhoto] {
        TyrePhotoStore.photos(for: record, inspection: inspection)
    }

    var body: some View {
        AppSettingsSection("Photos", caption: caption) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                if displayedPhotos.isEmpty {
                    Text("No photos yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppScreenMetrics.controlSpacing) {
                            ForEach(displayedPhotos) { photo in
                                TyrePhotoThumbnail(
                                    photo: photo,
                                    vehicleID: vehicleID,
                                    onTap: { viewerPhoto = photo },
                                    onDelete: {
                                        TyrePhotoStore.delete(photo: photo, vehicleID: vehicleID, in: modelContext)
                                    }
                                )
                            }
                        }
                    }
                }

                AppSecondaryButton("Add photo") {
                    showSourcePicker = true
                }

                if inspection == nil,
                   let sidewallPhoto = displayedPhotos.first(where: { $0.kind == .sidewall }),
                   let onAnalyzeSidewall {
                    AppSecondaryButton("Analyse latest sidewall photo") {
                        onAnalyzeSidewall(sidewallPhoto)
                    }
                }
            }
        }
        .confirmationDialog("Add photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showCamera = true }
            }
            Button("Choose from library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedLibraryItem, matching: .images)
        .onChange(of: selectedLibraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        pendingImage = image
                        showKindPicker = true
                        selectedLibraryItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            TyreImagePicker(sourceType: .camera) { image in
                pendingImage = image
                showKindPicker = true
            }
        }
        .confirmationDialog("Photo type", isPresented: $showKindPicker, titleVisibility: .visible) {
            ForEach(TyrePhotoKind.allCases) { kind in
                Button(kind.displayName) {
                    selectedKind = kind
                    savePendingImage()
                }
            }
            Button("Cancel", role: .cancel) {
                pendingImage = nil
            }
        } message: {
            Text("What does this photo show?")
        }
        .sheet(item: $viewerPhoto) { photo in
            TyrePhotoViewer(photo: photo, vehicleID: vehicleID)
        }
    }

    private func savePendingImage() {
        guard let pendingImage else { return }
        try? TyrePhotoStore.save(
            image: pendingImage,
            vehicleID: vehicleID,
            record: record,
            inspection: inspection,
            kind: selectedKind,
            in: modelContext
        )
        self.pendingImage = nil
    }
}

struct TyrePendingPhotoSection: View {
    @Binding var pendingImages: [(UIImage, TyrePhotoKind)]

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var showKindPicker = false
    @State private var viewerIndex: Int?

    var body: some View {
        AppSettingsSection(
            "Photos",
            caption: "Optional photos for this inspection. Stored on this device only — for your records, not automated analysis."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                if pendingImages.isEmpty {
                    Text("No photos added for this inspection yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppScreenMetrics.controlSpacing) {
                            ForEach(Array(pendingImages.enumerated()), id: \.offset) { index, entry in
                                Button {
                                    viewerIndex = index
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(uiImage: entry.0)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 88, height: 88)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        Text(entry.1.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSupporting)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        pendingImages.remove(at: index)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                AppSecondaryButton("Add photo") {
                    showSourcePicker = true
                }
            }
        }
        .confirmationDialog("Add photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showCamera = true }
            }
            Button("Choose from library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedLibraryItem, matching: .images)
        .onChange(of: selectedLibraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        pendingImage = image
                        showKindPicker = true
                        selectedLibraryItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            TyreImagePicker(sourceType: .camera) { image in
                pendingImage = image
                showKindPicker = true
            }
        }
        .confirmationDialog("Photo type", isPresented: $showKindPicker, titleVisibility: .visible) {
            ForEach(TyrePhotoKind.allCases) { kind in
                Button(kind.displayName) {
                    if let pendingImage {
                        pendingImages.append((pendingImage, kind))
                    }
                    self.pendingImage = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingImage = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { viewerIndex != nil },
            set: { if !$0 { viewerIndex = nil } }
        )) {
            if let index = viewerIndex, pendingImages.indices.contains(index) {
                TyreUIImageViewer(image: pendingImages[index].0, title: pendingImages[index].1.displayName)
            }
        }
    }
}

private struct TyrePhotoThumbnail: View {
    let photo: TyrePhoto
    let vehicleID: UUID
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if let image = TyrePhotoStore.loadImage(for: photo, vehicleID: vehicleID) {
            Button(action: onTap) {
                VStack(spacing: 4) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(photo.kind.displayName)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSupporting)
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete photo", systemImage: "trash")
                }
            }
        }
    }
}

private struct TyrePhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let photo: TyrePhoto
    let vehicleID: UUID

    var body: some View {
        NavigationStack {
            Group {
                if let image = TyrePhotoStore.loadImage(for: photo, vehicleID: vehicleID) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                            Text(photo.kind.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(Formatters.date(photo.capturedAt))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Photo unavailable", systemImage: "photo")
                }
            }
            .navigationTitle("Tyre photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct TyreUIImageViewer: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let title: String

    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

private struct TyreImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            DispatchQueue.main.async {
                context.coordinator.parent.dismiss()
            }
            picker.delegate = context.coordinator
            return picker
        }
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: TyreImagePicker

        init(parent: TyreImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct TyreInspectionPhotoStrip: View {
    let photos: [TyrePhoto]
    let vehicleID: UUID

    var body: some View {
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        if let image = TyrePhotoStore.loadImage(for: photo, vehicleID: vehicleID) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityLabel(photo.kind.displayName)
                        }
                    }
                }
            }
        }
    }
}
