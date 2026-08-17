import SwiftData
import UIKit
import XCTest
@testable import loadMate3

@MainActor
final class PhotoSyncMigrationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try LoadMateModelContainer.makePreview()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testMigratesExistingOnDiskPhotosIntoCloudKitData() throws {
        let profile = TestFixtures.motorhomeProfile()
        context.insert(profile)

        let plateName = try VehiclePlatePhotoStore.save(
            image: makeImage(color: .gray),
            to: profile
        )
        profile.manufacturerPlatePhotoData = nil

        let vehicleID = profile.id
        let accident = AccidentStore.createRecord(for: vehicleID, in: context)
        let accidentPhoto = try AccidentPhotoStore.save(
            image: makeImage(color: .blue, size: CGSize(width: 180, height: 120)),
            vehicleID: vehicleID,
            record: accident,
            kind: .road,
            in: context
        )
        accidentPhoto.imageData = nil

        let tyre = TyreRecord(vehicleID: vehicleID, position: .motorhomeFrontLeft)
        context.insert(tyre)
        let tyrePhoto = try TyrePhotoStore.save(
            image: makeImage(color: .red, size: CGSize(width: 180, height: 180)),
            vehicleID: vehicleID,
            record: tyre,
            inspection: nil,
            kind: .sidewall,
            in: context
        )
        tyrePhoto.imageData = nil

        let maintenance = MaintenanceRecord(vehicleID: vehicleID)
        context.insert(maintenance)
        let draft = try MaintenanceAttachmentStore.draft(
            image: makeImage(color: .green, size: CGSize(width: 200, height: 140)),
            fileType: .photo,
            displayName: "Service"
        )
        let attachment = try MaintenanceAttachmentStore.save(
            draft: draft,
            to: .maintenance(maintenance),
            in: context
        )
        attachment.fileData = nil
        attachment.thumbnailData = nil
        try context.save()

        XCTAssertTrue(PhotoSyncMigration.migrateLocalFilesIfNeeded(in: context))

        XCTAssertNotNil(profile.manufacturerPlatePhotoData)
        XCTAssertNotNil(accidentPhoto.imageData)
        XCTAssertNotNil(tyrePhoto.imageData)
        XCTAssertNotNil(attachment.fileData)
        XCTAssertNotNil(attachment.thumbnailData)

        try FileManager.default.removeItem(
            at: try VehiclePlatePhotoStore.fileURL(vehicleID: vehicleID, fileName: plateName)
        )
        try FileManager.default.removeItem(
            at: try AccidentPhotoStore.fileURL(vehicleID: vehicleID, fileName: accidentPhoto.localFileName)
        )
        try FileManager.default.removeItem(
            at: try TyrePhotoStore.fileURL(vehicleID: vehicleID, fileName: tyrePhoto.localFileName)
        )
        try FileManager.default.removeItem(
            at: try MaintenanceAttachmentStore.fileURL(vehicleID: vehicleID, fileName: attachment.localFileName)
        )

        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: profile))
        XCTAssertNotNil(AccidentPhotoStore.loadImage(for: accidentPhoto, vehicleID: vehicleID))
        XCTAssertNotNil(TyrePhotoStore.loadImage(for: tyrePhoto, vehicleID: vehicleID))
        XCTAssertNotNil(MaintenanceAttachmentStore.loadImage(for: attachment))
        XCTAssertFalse(PhotoSyncMigration.migrateLocalFilesIfNeeded(in: context))
    }

    private func makeImage(color: UIColor, size: CGSize = CGSize(width: 80, height: 50)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
