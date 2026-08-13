import SwiftData
import UIKit
import XCTest
@testable import loadMate3

@MainActor
final class VehicleProfileSyncReconciliationTests: XCTestCase {
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

    func testFactoryDefaultNameRecognition() {
        let caravan = VehicleProfile(name: "My Caravan", kind: .caravan)
        let numbered = VehicleProfile(name: "My Caravan1", kind: .caravan)
        let renamed = VehicleProfile(name: "Swift Challenger", kind: .caravan)
        let motorhome = VehicleProfile(name: "Motorhome", kind: .motorhome)

        XCTAssertTrue(VehicleProfileSyncReconciliation.isFactoryDefaultName(caravan))
        XCTAssertTrue(VehicleProfileSyncReconciliation.isFactoryDefaultFamilyName(numbered))
        XCTAssertFalse(VehicleProfileSyncReconciliation.isFactoryDefaultFamilyName(renamed))
        XCTAssertTrue(VehicleProfileSyncReconciliation.isFactoryDefaultName(motorhome))
    }

    func testMergesDuplicateNumberedDefaultCaravans() throws {
        let appState = AppState()
        context.insert(appState)

        context.insert(VehicleProfile(name: "My Caravan1", kind: .caravan))
        context.insert(VehicleProfile(name: "My Caravan1", kind: .caravan))

        let didChange = VehicleProfileSyncReconciliation.reconcile(in: context, appState: appState)

        XCTAssertTrue(didChange)
        XCTAssertEqual(try context.fetch(FetchDescriptor<VehicleProfile>()).count, 1)
    }

    func testMergesMyCaravanWithMyCaravan1() throws {
        let appState = AppState()
        context.insert(appState)

        let original = VehicleProfile(name: "My Caravan", kind: .caravan)
        original.mtplmKg = 1500
        context.insert(original)
        context.insert(VehicleProfile(name: "My Caravan1", kind: .caravan))

        _ = VehicleProfileSyncReconciliation.reconcile(in: context, appState: appState)

        let profiles = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.mtplmKg ?? 0, 1500, accuracy: 0.001)
    }

    func testMergesDuplicateDefaultCaravansKeepingRicherProfile() throws {
        let appState = AppState()
        context.insert(appState)

        let sparse = VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 0)
        let rich = VehicleProfile(
            id: LoadMateSyncIDs.defaultCaravanProfile,
            name: "My Caravan",
            kind: .caravan,
            sortOrder: 1
        )
        rich.mtplmKg = 1500
        rich.baseWeightKg = 1200
        rich.carMaxTowBallKg = 100

        let sparseTrip = Trip(name: TripStore.defaultTripName, profile: sparse)
        let item = LoadedItem(item: LibraryItem(name: "Awning", weightKg: 30), trip: sparseTrip)
        context.insert(sparse)
        context.insert(rich)
        context.insert(sparseTrip)
        context.insert(item)

        let didChange = VehicleProfileSyncReconciliation.reconcile(in: context, appState: appState)

        XCTAssertTrue(didChange)
        let profiles = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.id, LoadMateSyncIDs.defaultCaravanProfile)
        XCTAssertEqual(profiles.first?.mtplmKg ?? 0, 1500, accuracy: 0.001)

        let loaded = try context.fetch(FetchDescriptor<LoadedItem>())
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.trip?.profile?.id, LoadMateSyncIDs.defaultCaravanProfile)
    }

    func testMergesPlatePhotoOntoProfileWithoutOne() throws {
        let appState = AppState()
        context.insert(appState)

        let sparse = VehicleProfile(name: "My Caravan", kind: .caravan)
        let rich = VehicleProfile(
            id: LoadMateSyncIDs.defaultCaravanProfile,
            name: "My Caravan1",
            kind: .caravan
        )
        rich.mtplmKg = 1500
        context.insert(sparse)
        context.insert(rich)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 50))
        }
        try VehiclePlatePhotoStore.save(image: image, to: sparse)

        _ = VehicleProfileSyncReconciliation.reconcile(in: context, appState: appState)

        let profiles = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertFalse(profiles.first?.manufacturerPlatePhotoFileName.isEmpty ?? true)
        XCTAssertNotNil(profiles.first.flatMap { VehiclePlatePhotoStore.loadImage(for: $0) })
    }

    func testDoesNotMergeCustomNamedCaravanWithDefault() throws {
        let appState = AppState()
        context.insert(appState)

        context.insert(VehicleProfile(name: "My Caravan", kind: .caravan))
        context.insert(VehicleProfile(name: "Family Bailey", kind: .caravan))

        let didChange = VehicleProfileSyncReconciliation.reconcile(in: context, appState: appState)

        XCTAssertFalse(didChange)
        XCTAssertEqual(try context.fetch(FetchDescriptor<VehicleProfile>()).count, 2)
    }

    func testMergesDefaultTripsWithSameName() throws {
        let appState = AppState()
        context.insert(appState)

        let first = VehicleProfile(name: "My Motorhome", kind: .motorhome)
        let second = VehicleProfile(name: "My Motorhome", kind: .motorhome)
        let firstTrip = Trip(name: TripStore.defaultTripName, profile: first)
        let secondTrip = Trip(name: TripStore.defaultTripName, profile: second)
        let library = LibraryItem(name: "Bike", weightKg: 15)
        context.insert(first)
        context.insert(second)
        context.insert(firstTrip)
        context.insert(secondTrip)
        context.insert(library)
        context.insert(LoadedItem(item: library, trip: firstTrip))
        context.insert(LoadedItem(item: library, quantity: 2, trip: secondTrip))

        _ = VehicleProfileSyncReconciliation.reconcile(in: context, appState: appState)

        let profiles = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.tripsList.count, 1)

        let loaded = try context.fetch(FetchDescriptor<LoadedItem>())
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.trip?.profile?.id, profiles.first?.id)
        XCTAssertEqual(loaded.last?.trip?.profile?.id, profiles.first?.id)
    }
}
