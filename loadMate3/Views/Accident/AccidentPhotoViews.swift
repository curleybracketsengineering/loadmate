import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AccidentPhotoChecklistSection: View {
    @Environment(\.modelContext) private var modelContext

    let vehicleID: UUID
    let record: AccidentRecord
    let kinds: [AccidentPhotoKind]

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var pendingKind: AccidentPhotoKind = .other
    @State private var viewerPhoto: AccidentPhoto?

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            ForEach(kinds) { kind in
                photoKindRow(kind)
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
                        save(image)
                        selectedLibraryItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            AccidentImagePicker(sourceType: .camera) { image in
                save(image)
            }
        }
        .sheet(item: $viewerPhoto) { photo in
            AccidentPhotoViewer(photo: photo, vehicleID: vehicleID)
        }
    }

    private func photoKindRow(_ kind: AccidentPhotoKind) -> some View {
        let photos = AccidentPhotoStore.photos(of: kind, on: record)
        return VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            HStack(alignment: .center) {
                Image(systemName: photos.isEmpty ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(photos.isEmpty ? AppColors.textSupporting : AppColors.green)
                    .accessibilityHidden(true)
                Text(kind.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Button("Add") {
                    pendingKind = kind
                    showSourcePicker = true
                }
                .font(.subheadline.weight(.semibold))
            }

            Text(kind.guidance)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            if let image = AccidentPhotoStore.loadImage(for: photo, vehicleID: vehicleID) {
                                Button {
                                    viewerPhoto = photo
                                } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        AccidentPhotoStore.delete(photo: photo, vehicleID: vehicleID, in: modelContext)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private func save(_ image: UIImage) {
        try? AccidentPhotoStore.save(
            image: image,
            vehicleID: vehicleID,
            record: record,
            kind: pendingKind,
            in: modelContext
        )
    }
}

/// Camera / library capture for a single accident photo kind (licence, Green Card, etc.).
struct AccidentDocumentPhotoCaptureRow: View {
    @Environment(\.modelContext) private var modelContext

    let vehicleID: UUID
    let record: AccidentRecord
    let kind: AccidentPhotoKind
    var emptyIcon: String = "doc.text.image"
    /// When set, only photos with this caption are shown/managed.
    var captionFilter: String? = nil
    var captionOnSave: String = ""
    var confirmationMessage: String? = nil
    var onSaved: (() -> Void)? = nil
    /// Called with the captured image after it is stored (for OCR fill-in).
    var onImageSaved: ((UIImage) -> Void)? = nil

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var viewerPhoto: AccidentPhoto?

    private var photos: [AccidentPhoto] {
        record.photosList.filter { photo in
            guard photo.kind == kind else { return false }
            if let captionFilter {
                return photo.caption == captionFilter
            }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: photos.isEmpty ? emptyIcon : "checkmark.circle.fill")
                    .foregroundStyle(photos.isEmpty ? AppColors.textSupporting : AppColors.green)
                    .accessibilityHidden(true)

                Text(kind.displayName)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Button(photos.isEmpty ? "Add photo" : "Add another") {
                    showSourcePicker = true
                }
                .font(.subheadline.weight(.semibold))
            }

            Text(kind.guidance)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            if let image = AccidentPhotoStore.loadImage(for: photo, vehicleID: vehicleID) {
                                Button {
                                    viewerPhoto = photo
                                } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        AccidentPhotoStore.delete(
                                            photo: photo,
                                            vehicleID: vehicleID,
                                            in: modelContext
                                        )
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Add \(kind.displayName.lowercased()) photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showCamera = true }
            }
            Button("Choose from library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let confirmationMessage {
                Text(confirmationMessage)
            }
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedLibraryItem, matching: .images)
        .onChange(of: selectedLibraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        save(image)
                        selectedLibraryItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            AccidentImagePicker(sourceType: .camera) { image in
                save(image)
            }
        }
        .sheet(item: $viewerPhoto) { photo in
            AccidentPhotoViewer(photo: photo, vehicleID: vehicleID)
        }
    }

    private func save(_ image: UIImage) {
        try? AccidentPhotoStore.save(
            image: image,
            vehicleID: vehicleID,
            record: record,
            kind: kind,
            caption: captionOnSave,
            in: modelContext
        )
        onSaved?()
        onImageSaved?(image)
    }
}

struct AccidentDrivingLicencePhotoRow: View {
    @Environment(\.modelContext) private var modelContext

    let vehicleID: UUID
    let record: AccidentRecord
    let vehicle: AccidentOtherVehicle

    @State private var ocrStatus: String?

    private var storageKey: String {
        "driving-licence:\(vehicle.id.uuidString)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AccidentDocumentPhotoCaptureRow(
                vehicleID: vehicleID,
                record: record,
                kind: .drivingLicence,
                emptyIcon: "person.text.rectangle",
                captionFilter: storageKey,
                captionOnSave: storageKey,
                confirmationMessage: "Only continue if the driver has offered the licence and agrees to it being photographed.",
                onImageSaved: { image in
                    Task {
                        await runLicenceOCR(image)
                    }
                }
            )

            if let ocrStatus {
                Text(ocrStatus)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("UK and EU photocards supported. Check the filled fields against the photo.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @MainActor
    private func runLicenceOCR(_ image: UIImage) async {
        ocrStatus = "Reading licence…"
        do {
            let suggestions = try await DrivingLicenceOCR.analyze(image: image)
            guard suggestions.hasUsefulFields else {
                ocrStatus = "Could not read name or address — enter them manually."
                return
            }

            var filled: [String] = []
            if vehicle.driverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !suggestions.fullName.isEmpty {
                vehicle.driverName = suggestions.fullName
                filled.append("name")
            }
            if vehicle.driverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !suggestions.address.isEmpty {
                vehicle.driverAddress = suggestions.address
                filled.append("address")
            }

            AccidentStore.save(record, in: modelContext)

            if filled.isEmpty {
                ocrStatus = "Licence saved. Name/address already filled — check they match the photo."
            } else {
                ocrStatus = "Filled \(filled.joined(separator: " and ")) from licence. Please check."
            }
        } catch {
            ocrStatus = "Could not read the licence — enter details manually."
        }
    }
}

struct AccidentPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photo: AccidentPhoto
    let vehicleID: UUID

    var body: some View {
        NavigationStack {
            Group {
                if let image = AccidentPhotoStore.loadImage(for: photo, vehicleID: vehicleID) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("Photo could not be loaded.")
                        .foregroundStyle(AppColors.textSupporting)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appScreenBackground()
            .navigationTitle(photo.kind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AccidentImagePicker: UIViewControllerRepresentable {
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
        let parent: AccidentImagePicker

        init(parent: AccidentImagePicker) {
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
