import XCTest
@testable import loadMate3

final class MotorhomeWeighbridgeValidationTests: XCTestCase {
    func testConsistentAxleWeightsPassValidation() {
        let profile = TestFixtures.motorhomeProfile(gross: 3000, frontAxle: 1350, rearAxle: 1650)

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        XCTAssertTrue(result.isConsistent)
        XCTAssertNil(result.bannerMessage)
    }

    func testConflictingAxleSumReportsIssue() {
        let profile = TestFixtures.motorhomeProfile(gross: 3000, frontAxle: 1500, rearAxle: 1700)

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        XCTAssertFalse(result.isConsistent)
        XCTAssertFalse(result.allMessages.isEmpty)
    }

    func testGrossOverMAMReportsIssue() {
        var profile = TestFixtures.motorhomeProfile(gross: 3600, frontAxle: 1800, rearAxle: 1800, mam: 3500)

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        XCTAssertFalse(result.isConsistent)
        XCTAssertTrue(result.allMessages.contains { $0.contains("exceeds MAM") })
    }

    func testAxleWeightsMatchGrossWithinTolerance() {
        XCTAssertTrue(MotorhomeWeighbridgeValidation.axleWeightsMatchGross(axleSum: 3005, gross: 3000))
        XCTAssertFalse(MotorhomeWeighbridgeValidation.axleWeightsMatchGross(axleSum: 3020, gross: 3000))
    }

    func testShouldUseAxleSumWhenGrossMissing() {
        let profile = TestFixtures.motorhomeProfile(gross: 0, frontAxle: 1350, rearAxle: 1650)

        XCTAssertTrue(MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: profile))
        XCTAssertEqual(profile.calculationBaseWeightKg, 3000, accuracy: 0.001)
    }

    func testShouldPreferGrossWhenAxlesConflict() {
        let profile = TestFixtures.motorhomeProfile(gross: 3000, frontAxle: 1500, rearAxle: 1700)

        XCTAssertFalse(MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: profile))
        XCTAssertTrue(profile.motorhomeHasConflictingWeighbridgeEntries)
        XCTAssertEqual(profile.calculationBaseWeightKg, 3000, accuracy: 0.001)
    }

    func testCaravanProfilesSkipValidation() {
        let profile = TestFixtures.caravanProfile()

        XCTAssertTrue(MotorhomeWeighbridgeValidation.validate(profile: profile).isConsistent)
        XCTAssertFalse(profile.motorhomeHasConflictingWeighbridgeEntries)
    }
}
