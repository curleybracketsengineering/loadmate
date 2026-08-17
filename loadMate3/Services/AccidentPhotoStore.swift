import Foundation
import SwiftData
import UIKit

enum AccidentPhotoStoreError: Error {
    case encodeFailed
}

enum AccidentPhotoStore {
    private static let subdirectoryName = "AccidentPhotos"
    private static let maxPixelDimension: CGFloat = 2048
    private static let jpegQuality: CGFloat = 0.8

    static func directoryURL(vehicleID: UUID) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent(subdirectoryName, isDirectory: true)
            .appendingPathComponent(vehicleID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func fileURL(vehicleID: UUID, fileName: String) throws -> URL {
        try directoryURL(vehicleID: vehicleID).appendingPathComponent(fileName)
    }

    @discardableResult
    static func save(
        image: UIImage,
        vehicleID: UUID,
        record: AccidentRecord,
        kind: AccidentPhotoKind,
        caption: String = "",
        in context: ModelContext
    ) throws -> AccidentPhoto {
        let prepared = TyrePhotoStore.resize(image: image, maxDimension: maxPixelDimension)
        guard let data = prepared.jpegData(compressionQuality: jpegQuality) else {
            throw AccidentPhotoStoreError.encodeFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let url = try fileURL(vehicleID: vehicleID, fileName: fileName)
        try data.write(to: url, options: .atomic)

        let photo = AccidentPhoto(
            vehicleID: vehicleID,
            record: record,
            kind: kind,
            localFileName: fileName
        )
        photo.caption = caption
        photo.imageData = data
        context.insert(photo)
        record.updatedAt = Date()
        try context.save()
        return photo
    }

    static func loadData(for photo: AccidentPhoto, vehicleID: UUID) -> Data? {
        if let data = PhotoSyncSupport.nonEmpty(photo.imageData) {
            return data
        }
        return loadLocalFileData(for: photo, vehicleID: vehicleID)
    }

    static func loadImage(for photo: AccidentPhoto, vehicleID: UUID) -> UIImage? {
        guard let data = loadData(for: photo, vehicleID: vehicleID) else { return nil }
        return UIImage(data: data)
    }

    static func loadLocalFileData(for photo: AccidentPhoto, vehicleID: UUID) -> Data? {
        PhotoSyncSupport.fileData(
            vehicleID: vehicleID,
            fileName: photo.localFileName,
            fileURL: fileURL
        )
    }

    @discardableResult
    static func migrateLocalFileIfNeeded(for photo: AccidentPhoto, vehicleID: UUID) -> Bool {
        guard PhotoSyncSupport.nonEmpty(photo.imageData) == nil,
              let data = loadLocalFileData(for: photo, vehicleID: vehicleID) else {
            return false
        }
        photo.imageData = data
        return true
    }

    static func delete(
        photo: AccidentPhoto,
        vehicleID: UUID,
        in context: ModelContext,
        saveContext: Bool = true
    ) {
        if let url = try? fileURL(vehicleID: vehicleID, fileName: photo.localFileName) {
            try? FileManager.default.removeItem(at: url)
        }
        if let record = photo.record {
            record.updatedAt = Date()
        }
        context.delete(photo)
        if saveContext {
            try? context.save()
        }
    }

    static func photos(of kind: AccidentPhotoKind, on record: AccidentRecord) -> [AccidentPhoto] {
        record.photosList.filter { $0.kind == kind }
    }
}
