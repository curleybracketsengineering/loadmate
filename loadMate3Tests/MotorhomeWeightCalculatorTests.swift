import XCTest
@testable import loadMate3

final class MotorhomeWeightCalculatorTests: XCTestCase {
    func testSummaryUsesAxleBaselinesWhenWeighbridgeMatches() {
        let profile = TestFixtures.motorhomeProfile()
        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [])

        XCTAssertEqual(summary.baselineFrontAxleKg, 1350, accuracy: 0.001)
        XCTAssertEqual(summary.baselineRearAxleKg, 1650, accuracy: 0.001)
        XCTAssertEqual(summary.totalWeightKg, 3000, accuracy: 0.001)
        XCTAssertTrue(summary.isOverallSafe)
    }

    func testGarageLoadCountsTowardGarageLimit() {
        let profile = TestFixtures.motorhomeProfile(maxGarage: 100)
        let item = TestFixtures.libraryItem(name: "Scooter", weightKg: 120)
        let loaded = TestFixtures.loadedItem(item: item, zone: .garage)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [loaded])

        XCTAssertEqual(summary.garageLoadedKg, 120, accuracy: 0.001)
        XCTAssertTrue(summary.isOverGarageLimit)
        XCTAssertFalse(summary.isOverallSafe)
    }

    func testTowBarLoadAddsToRearAxleAndGross() {
        let profile = TestFixtures.motorhomeProfile(usesTowBar: true, maxTowBar: 100)
        let trip = TestFixtures.trip(profile: profile, towBarLoad: 75)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [], trip: trip)

        XCTAssertEqual(summary.towBarLoadKg, 75, accuracy: 0.001)
        XCTAssertEqual(summary.rearAxleImpactKg, 75, accuracy: 0.001)
        XCTAssertEqual(summary.totalWeightKg, 3075, accuracy: 0.001)
        XCTAssertFalse(summary.isTowBarMeasurementMissing)
    }

    func testMissingTowBarMeasurementWhenMonitoringEnabled() {
        let profile = TestFixtures.motorhomeProfile(usesTowBar: true, maxTowBar: 100)
        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [], trip: nil)

        XCTAssertTrue(summary.isTowBarMeasurementMissing)
        XCTAssertFalse(summary.isOverallSafe)
    }

    func testDriverZoneLoadsMostlyFrontAxle() {
        let profile = TestFixtures.motorhomeProfile()
        let item = TestFixtures.libraryItem(name: "Passenger", weightKg: 80)
        let loaded = TestFixtures.loadedItem(item: item, zone: .driver)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [loaded])
        let factors = MotorhomeWeightCalculator.frontRearFactors(for: .driver, profile: profile)

        XCTAssertEqual(summary.frontAxleImpactKg, 80 * factors.front, accuracy: 0.001)
        XCTAssertEqual(summary.rearAxleImpactKg, 80 * factors.rear, accuracy: 0.001)
    }

    func testOverFrontAxleLimit() {
        let profile = TestFixtures.motorhomeProfile(maxFront: 1400)
        let item = TestFixtures.libraryItem(name: "Toolbox", weightKg: 100)
        let loaded = TestFixtures.loadedItem(item: item, zone: .driver)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [loaded])

        XCTAssertTrue(summary.isOverFrontAxle)
    }
}
