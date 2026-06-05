import Testing
import SwiftData
@testable import loadMate3

@MainActor
@Suite("Motorhome weighbridge validation")
struct MotorhomeWeighbridgeValidationTests {
    @Test("Consistent gross and axle figures produce no issues")
    func consistentFiguresAreClean() throws {
        let (_, profile, _) = try TestSupport.makeMotorhome(
            weighbridgeWeightKg: 3000,
            weighbridgeFrontAxleKg: 1350,
            weighbridgeRearAxleKg: 1650,
            mamKg: 3500
        )

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        #expect(result.isConsistent)
        #expect(result.bannerMessage == nil)
    }

    @Test("Gross exceeding MAM is reported")
    func grossOverMam() throws {
        let (_, profile, _) = try TestSupport.makeMotorhome(weighbridgeWeightKg: 3600, mamKg: 3500)

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        #expect(!result.isConsistent)
        #expect(result.allMessages.contains { $0.contains("exceeds MAM") })
    }

    @Test("Axle total above MAM is reported")
    func axleSumOverMam() throws {
        let (_, profile, _) = try TestSupport.makeMotorhome(
            weighbridgeFrontAxleKg: 1800,
            weighbridgeRearAxleKg: 1800,
            mamKg: 3500
        )

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        #expect(!result.isConsistent)
    }

    @Test("Axle sum and gross differing beyond tolerance is reported")
    func axleSumVsGrossMismatch() throws {
        let (_, profile, _) = try TestSupport.makeMotorhome(
            weighbridgeWeightKg: 3000,
            weighbridgeFrontAxleKg: 1350,
            weighbridgeRearAxleKg: 1500, // sum 2850, 150 under gross
            mamKg: 3500
        )

        let result = MotorhomeWeighbridgeValidation.validate(profile: profile)

        #expect(!result.isConsistent)
    }

    @Test("Differences within the 10 kg tolerance are accepted")
    func withinToleranceMatches() {
        #expect(MotorhomeWeighbridgeValidation.axleWeightsMatchGross(axleSum: 3005, gross: 3000))
        #expect(!MotorhomeWeighbridgeValidation.axleWeightsMatchGross(axleSum: 3030, gross: 3000))
        #expect(!MotorhomeWeighbridgeValidation.axleWeightsMatchGross(axleSum: 0, gross: 3000))
    }

    @Test("Axle sum drives base weight only when it matches gross")
    func shouldUseAxleSumForBaseWeight() throws {
        // Matching axle sum + gross -> prefer axle sum.
        let (_, matching, _) = try TestSupport.makeMotorhome(
            weighbridgeWeightKg: 3000,
            weighbridgeFrontAxleKg: 1350,
            weighbridgeRearAxleKg: 1650
        )
        #expect(MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: matching))
        #expect(abs(matching.calculationBaseWeightKg - 3000) < 0.0001)

        // Conflicting axle sum + gross -> gross wins.
        let (_, conflicting, _) = try TestSupport.makeMotorhome(
            weighbridgeWeightKg: 3000,
            weighbridgeFrontAxleKg: 1350,
            weighbridgeRearAxleKg: 1500
        )
        #expect(!MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: conflicting))
        #expect(conflicting.motorhomeHasConflictingWeighbridgeEntries)
        #expect(abs(conflicting.calculationBaseWeightKg - 3000) < 0.0001)

        // Only axle sum entered -> use it.
        let (_, axleOnly, _) = try TestSupport.makeMotorhome(
            weighbridgeFrontAxleKg: 1400,
            weighbridgeRearAxleKg: 1600
        )
        #expect(MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: axleOnly))
        #expect(abs(axleOnly.calculationBaseWeightKg - 3000) < 0.0001)
    }

    @Test("Validation ignores caravans")
    func caravanIsAlwaysConsistent() throws {
        let (_, caravan, _) = try TestSupport.makeCaravan()
        #expect(MotorhomeWeighbridgeValidation.validate(profile: caravan).isConsistent)
    }
}
