import XCTest
@testable import loadMate3

final class LoadZoneTests: XCTestCase {
    func testCaravanZonesMapToMotorhomeZones() {
        XCTAssertEqual(LoadZone.resolved(rawValue: LoadZone.frontLocker.rawValue, for: .motorhome), .driver)
        XCTAssertEqual(LoadZone.resolved(rawValue: LoadZone.front.rawValue, for: .motorhome), .central)
        XCTAssertEqual(LoadZone.resolved(rawValue: LoadZone.middle.rawValue, for: .motorhome), .central)
        XCTAssertEqual(LoadZone.resolved(rawValue: LoadZone.rear.rawValue, for: .motorhome), .back)
        XCTAssertEqual(LoadZone.resolved(rawValue: LoadZone.garage.rawValue, for: .motorhome), .garage)
    }

    func testUnassignedDefaultsToMiddleForCaravan() {
        XCTAssertEqual(LoadZone.unassigned.calculationZone(for: .caravan), .middle)
    }

    func testUnassignedDefaultsToCentralForMotorhome() {
        XCTAssertEqual(LoadZone.unassigned.calculationZone(for: .motorhome), .central)
    }

    func testPickerZonesExcludeBikeRackWhenProfileHasNone() {
        let profile = TestFixtures.caravanProfile()
        profile.hasBikeRack = false

        let zones = LoadZone.pickerZones(for: .caravan, profile: profile)

        XCTAssertFalse(zones.contains(.bikeRack))
        XCTAssertTrue(zones.contains(.frontLocker))
    }

    func testPickerZonesIncludeBikeRackWhenEnabled() {
        let profile = TestFixtures.motorhomeProfile()
        profile.hasBikeRack = true

        let zones = LoadZone.pickerZones(for: .motorhome, profile: profile)

        XCTAssertTrue(zones.contains(.bikeRack))
    }
}
