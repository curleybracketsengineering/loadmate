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

    func testMotorhomeSetupSummaryMessageListsMissingFields() {
        var profile = TestFixtures.motorhomeProfile(gross: 0, frontAxle: 0, rearAxle: 0, mam: 0)
        profile.baseWeightKg = 0
        profile.maxFrontAxleKg = 0
        profile.maxRearAxleKg = 1850

        XCTAssertFalse(profile.isConfiguredForWeightCalculations)
        XCTAssertEqual(
            profile.missingWeightCalculationFieldLabels,
            ["MRO (kg) or weighbridge weight", "MAM (kg)", "Max front axle (kg)"]
        )
        XCTAssertEqual(
            profile.weightCalculationSetupSummaryMessage,
            "Can't show summary information until MRO (kg) or weighbridge weight, MAM (kg), and Max front axle (kg) have been completed in Settings."
        )
    }

    func testCaravanSetupSummaryMessageListsSingleMissingField() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1200, mtplm: 1500, towBall: 0)

        XCTAssertFalse(profile.isConfiguredForWeightCalculations)
        XCTAssertEqual(profile.missingWeightCalculationFieldLabels, ["Car tow ball limit (kg)"])
        XCTAssertEqual(
            profile.weightCalculationSetupSummaryMessage,
            "Can't show summary information until Car tow ball limit (kg) has been completed in Settings."
        )
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
