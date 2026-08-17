import Foundation
import UIKit

enum VehiclePlatePhotoStoreError: Error {
    case encodeFailed
}

/// Manufacturer-plate photo for a vehicle profile. Bytes live on the SwiftData
/// model so CloudKit can sync them; a local file is kept as a cache.
enum VehiclePlatePhotoStore {
    private static let subdirectoryName = "VehiclePlatePhotos"
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
    static func save(image: UIImage, to profile: VehicleProfile) throws -> String {
        let prepared = resize(image: image, maxDimension: maxPixelDimension)
        guard let data = prepared.jpegData(compressionQuality: jpegQuality) else {
            throw VehiclePlatePhotoStoreError.encodeFailed
        }
        return try apply(data: data, to: profile)
    }

    static func hasPhoto(_ profile: VehicleProfile) -> Bool {
        loadData(for: profile) != nil
    }

    static func loadData(for profile: VehicleProfile) -> Data? {
        if let data = PhotoSyncSupport.nonEmpty(profile.manufacturerPlatePhotoData) {
            return data
        }
        return loadLocalFileData(for: profile)
    }

    static func loadImage(for profile: VehicleProfile) -> UIImage? {
        guard let data = loadData(for: profile) else { return nil }
        return UIImage(data: data)
    }

    static func loadLocalFileData(for profile: VehicleProfile) -> Data? {
        PhotoSyncSupport.fileData(
            vehicleID: profile.id,
            fileName: profile.manufacturerPlatePhotoFileName,
            fileURL: fileURL
        )
    }

    /// Copies on-disk JPEG bytes onto the model so CloudKit can export them.
    @discardableResult
    static func migrateLocalFileIfNeeded(for profile: VehicleProfile) -> Bool {
        guard PhotoSyncSupport.nonEmpty(profile.manufacturerPlatePhotoData) == nil,
              let data = loadLocalFileData(for: profile) else {
            return false
        }
        profile.manufacturerPlatePhotoData = data
        return true
    }

    static func delete(for profile: VehicleProfile) {
        deleteFiles(forVehicleID: profile.id)
        profile.manufacturerPlatePhotoFileName = ""
        profile.manufacturerPlatePhotoData = nil
    }

    static func deleteFiles(forVehicleID vehicleID: UUID) {
        guard let directory = try? directoryURL(vehicleID: vehicleID) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Copies a plate photo onto another profile (CloudKit duplicate merge).
    static func transferIfNeeded(from source: VehicleProfile, to target: VehicleProfile) {
        guard !hasPhoto(target), let data = loadData(for: source) else { return }
        try? apply(data: data, to: target)
    }

    static func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    @discardableResult
    private static func apply(data: Data, to profile: VehicleProfile) throws -> String {
        deleteFiles(forVehicleID: profile.id)

        let fileName = "\(UUID().uuidString).jpg"
        let url = try fileURL(vehicleID: profile.id, fileName: fileName)
        try data.write(to: url, options: .atomic)
        profile.manufacturerPlatePhotoFileName = fileName
        profile.manufacturerPlatePhotoData = data
        return fileName
    }
}
