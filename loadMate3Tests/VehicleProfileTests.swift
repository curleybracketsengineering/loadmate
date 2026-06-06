import XCTest
@testable import loadMate3

final class VehicleProfileTests: XCTestCase {
    func testEffectiveMaxTowBallUsesLowerCaravanLimit() {
        let profile = TestFixtures.caravanProfile(towBall: 120)
        profile.caravanMaxNoseKg = 90

        XCTAssertEqual(profile.effectiveMaxTowBallKg, 90, accuracy: 0.001)
    }

    func testCaravanConfiguredWhenRequiredFieldsPresent() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1200, mtplm: 1500, towBall: 100)

        XCTAssertTrue(profile.isConfiguredForWeightCalculations)
    }

    func testMotorhomeConfiguredWhenAxleLimitsPresent() {
        let profile = TestFixtures.motorhomeProfile()

        XCTAssertTrue(profile.isConfiguredForWeightCalculations)
    }

    func testCaravanUsesWeighbridgeOverBaseWeight() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1200, weighbridge: 1300, mtplm: 1500, towBall: 100)

        XCTAssertEqual(profile.calculationBaseWeightKg, 1300, accuracy: 0.001)
    }

    func testNoseSafeZoneReferenceUsesLadenWeightWhenConfigured() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1000, mtplm: 2000, towBall: 100)
        profile.noseSafeZoneBasis = .ladenWeight

        XCTAssertEqual(profile.noseSafeZoneReferenceWeightKg(totalLadenWeightKg: 1100), 1100, accuracy: 0.001)
    }

    func testGrossMassLabelReflectsVehicleKind() {
        XCTAssertEqual(TestFixtures.caravanProfile().grossMassLabel, "MTPLM")
        XCTAssertEqual(TestFixtures.motorhomeProfile().grossMassLabel, "MAM")
    }
}
