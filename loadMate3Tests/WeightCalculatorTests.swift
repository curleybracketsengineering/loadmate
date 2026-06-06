import XCTest
@testable import loadMate3

final class WeightCalculatorTests: XCTestCase {
    func testSummaryWithNoLoadedItemsUsesBaseWeight() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1200, mtplm: 1500, towBall: 100)
        let summary = WeightCalculator.summary(profile: profile, loadedItems: [])

        XCTAssertEqual(summary.loadedWeightKg, 0)
        XCTAssertEqual(summary.totalWeightKg, 1200)
        XCTAssertEqual(summary.availableWeightKg, 300)
        XCTAssertFalse(summary.isOverMTPLM)
    }

    func testFrontLockerIncreasesNoseWeight() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1000, mtplm: 1500, towBall: 150)
        let item = TestFixtures.libraryItem(name: "Gas bottle", weightKg: 10)
        let loaded = TestFixtures.loadedItem(item: item, zone: .frontLocker)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: [loaded])

        XCTAssertEqual(summary.locationImpactKg, 2.5, accuracy: 0.001)
        XCTAssertGreaterThan(summary.estimatedNoseWeightKg, summary.baseNosePercentKg)
    }

    func testRearLoadDecreasesNoseWeight() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1000, mtplm: 1500, towBall: 150)
        let item = TestFixtures.libraryItem(name: "Awning", weightKg: 20)
        let loaded = TestFixtures.loadedItem(item: item, zone: .rear)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: [loaded])

        XCTAssertEqual(summary.locationImpactKg, -4.0, accuracy: 0.001)
        XCTAssertLessThan(summary.estimatedNoseWeightKg, summary.baseNosePercentKg + 60)
    }

    func testOverMTPLMFlag() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1400, mtplm: 1500, towBall: 100)
        let item = TestFixtures.libraryItem(name: "Heavy kit", weightKg: 200)
        let loaded = TestFixtures.loadedItem(item: item, zone: .middle)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: [loaded])

        XCTAssertTrue(summary.isOverMTPLM)
        XCTAssertFalse(summary.isOverallSafe)
    }

    func testTowVehicleUnsuitableWhenMinimumNoseExceedsLimit() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1000, mtplm: 2000, towBall: 40)
        let summary = WeightCalculator.summary(profile: profile, loadedItems: [])

        XCTAssertTrue(summary.isTowVehicleUnsuitable)
    }

    func testNoseSafeZoneUsesMTPLMWhenConfigured() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1000, mtplm: 2000, towBall: 150)
        profile.noseSafeZoneBasis = .mtplm
        let summary = WeightCalculator.summary(profile: profile, loadedItems: [])

        XCTAssertEqual(summary.towBallMinKg, 100, accuracy: 0.001)
        XCTAssertEqual(summary.towBallMaxKg, 140, accuracy: 0.001)
    }

    func testMTPLMFillFractionCapsAtOne() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1600, mtplm: 1500, towBall: 100)
        let summary = WeightCalculator.summary(profile: profile, loadedItems: [])

        XCTAssertEqual(summary.mtplmFillFraction(profile: profile), 1.0, accuracy: 0.001)
    }
}
