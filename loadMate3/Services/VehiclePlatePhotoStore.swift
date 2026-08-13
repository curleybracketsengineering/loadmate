import Foundation
import UIKit

enum VehiclePlatePhotoStoreError: Error {
    case encodeFailed
}

/// Local manufacturer-plate photo for a vehicle profile (Settings thumbnail).
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
        deleteFiles(forVehicleID: profile.id)

        let prepared = resize(image: image, maxDimension: maxPixelDimension)
        guard let data = prepared.jpegData(compressionQuality: jpegQuality) else {
            throw VehiclePlatePhotoStoreError.encodeFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let url = try fileURL(vehicleID: profile.id, fileName: fileName)
        try data.write(to: url, options: .atomic)
        profile.manufacturerPlatePhotoFileName = fileName
        return fileName
    }

    static func loadImage(for profile: VehicleProfile) -> UIImage? {
        let fileName = profile.manufacturerPlatePhotoFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty,
              let url = try? fileURL(vehicleID: profile.id, fileName: fileName),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func delete(for profile: VehicleProfile) {
        deleteFiles(forVehicleID: profile.id)
        profile.manufacturerPlatePhotoFileName = ""
    }

    static func deleteFiles(forVehicleID vehicleID: UUID) {
        guard let directory = try? directoryURL(vehicleID: vehicleID) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Copies a plate photo onto another profile (CloudKit duplicate merge).
    static func transferIfNeeded(from source: VehicleProfile, to target: VehicleProfile) {
        let targetName = target.manufacturerPlatePhotoFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard targetName.isEmpty, let image = loadImage(for: source) else { return }
        try? save(image: image, to: target)
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
}
