import Foundation
import SwiftData

/// Shared helpers for CloudKit-backed photo and attachment bytes.
enum PhotoSyncSupport {
    static func nonEmpty(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        return data
    }

    static func fileData(
        vehicleID: UUID,
        fileName: String,
        fileURL: (UUID, String) throws -> URL
    ) -> Data? {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = try? fileURL(vehicleID, trimmed),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return nonEmpty(data)
    }
}

/// Copies existing on-disk photos/attachments onto SwiftData so CloudKit can export them.
enum PhotoSyncMigration {
    @MainActor
    @discardableResult
    static func migrateLocalFilesIfNeeded(in context: ModelContext) -> Bool {
        var didChange = false

        if let profiles = try? context.fetch(FetchDescriptor<VehicleProfile>()) {
            for profile in profiles {
                if VehiclePlatePhotoStore.migrateLocalFileIfNeeded(for: profile) {
                    didChange = true
                }
            }
        }

        if let photos = try? context.fetch(FetchDescriptor<AccidentPhoto>()) {
            for photo in photos {
                if AccidentPhotoStore.migrateLocalFileIfNeeded(for: photo, vehicleID: photo.vehicleID) {
                    didChange = true
                }
            }
        }

        if let photos = try? context.fetch(FetchDescriptor<TyrePhoto>()) {
            for photo in photos {
                guard let vehicleID = photo.tyreRecord?.vehicleID else { continue }
                if TyrePhotoStore.migrateLocalFileIfNeeded(for: photo, vehicleID: vehicleID) {
                    didChange = true
                }
            }
        }

        if let attachments = try? context.fetch(FetchDescriptor<MaintenanceAttachment>()) {
            for attachment in attachments {
                if MaintenanceAttachmentStore.migrateLocalFileIfNeeded(for: attachment) {
                    didChange = true
                }
            }
        }

        if didChange {
            _ = SyncDebugSaveHelper.save(context, source: "PhotoSyncMigration.migrateLocalFilesIfNeeded")
        }
        return didChange
    }
}
