import Testing
import SwiftData
@testable import loadMate3

@MainActor
@Suite("Caravan weight calculator")
struct WeightCalculatorTests {
    private let tolerance = 0.0001

    @Test("Sums loaded mass, total, available and MTPLM percentage")
    func totalsAndHeadroom() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 100, zone: .middle, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(abs(summary.loadedWeightKg - 100) < tolerance)
        #expect(abs(summary.totalWeightKg - 1350) < tolerance)
        #expect(abs(summary.availableWeightKg - 150) < tolerance)
        #expect(abs(summary.mtplmPercent - 90) < tolerance)
    }

    @Test("Quantity multiplies item mass")
    func quantityMultipliesMass() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 10, quantity: 3, zone: .middle, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(abs(summary.loadedWeightKg - 30) < tolerance)
    }

    @Test("Front locker increases nose weight; middle is neutral; rear decreases it")
    func zoneFactorsDriveLocationImpact() throws {
        // Front locker: factor 0.25
        let (frontCtx, frontProfile, frontTrip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 100, zone: .frontLocker, trip: frontTrip, in: frontCtx)
        let front = WeightCalculator.summary(profile: frontProfile, loadedItems: frontTrip.loadedItems ?? [])
        #expect(abs(front.locationImpactKg - 25) < tolerance)

        // Middle (axle): factor 0.0
        let (midCtx, midProfile, midTrip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 100, zone: .middle, trip: midTrip, in: midCtx)
        let middle = WeightCalculator.summary(profile: midProfile, loadedItems: midTrip.loadedItems ?? [])
        #expect(abs(middle.locationImpactKg - 0) < tolerance)

        // Rear: factor -0.20
        let (rearCtx, rearProfile, rearTrip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 100, zone: .rear, trip: rearTrip, in: rearCtx)
        let rear = WeightCalculator.summary(profile: rearProfile, loadedItems: rearTrip.loadedItems ?? [])
        #expect(abs(rear.locationImpactKg - (-20)) < tolerance)
    }

    @Test("Estimated nose weight = base percent of laden + location impact")
    func estimatedNoseWeight() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 100, zone: .frontLocker, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        // base = 1350 * 6% = 81, impact = 100 * 0.25 = 25
        #expect(abs(summary.baseNosePercentKg - 81) < tolerance)
        #expect(abs(summary.estimatedNoseWeightKg - 106) < tolerance)
    }

    @Test("Tow ball safe band is 5%–7% of the reference mass")
    func towBallBand() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan(mtplmKg: 1500, noseSafeZoneBasis: .mtplm)
        TestSupport.addLoadedItem(weightKg: 100, zone: .middle, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        // MTPLM basis -> reference 1500
        #expect(abs(summary.towBallMinKg - 75) < tolerance)
        #expect(abs(summary.towBallMaxKg - 105) < tolerance)
    }

    @Test("Laden basis uses current total weight for the safe band")
    func towBallBandUsesLadenBasis() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan(mtplmKg: 1500, noseSafeZoneBasis: .ladenWeight)
        TestSupport.addLoadedItem(weightKg: 100, zone: .middle, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        // Laden basis -> reference 1350
        #expect(abs(summary.towBallMinKg - 67.5) < tolerance)
        #expect(abs(summary.towBallMaxKg - 94.5) < tolerance)
    }

    @Test("Flags over-MTPLM when total exceeds the gross limit")
    func overMTPLM() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan(mtplmKg: 1300)
        TestSupport.addLoadedItem(weightKg: 100, zone: .middle, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(summary.isOverMTPLM)
        #expect(!summary.isOverallSafe)
        #expect(summary.availableWeightKg < 0)
    }

    @Test("Flags nose weight above tow-ball limit and above recommended band")
    func overTowBallAndAboveRecommended() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan(carMaxTowBallKg: 100)
        // Heavy in front locker pushes nose past the 100 kg cap and past 7% band.
        TestSupport.addLoadedItem(weightKg: 100, zone: .frontLocker, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(summary.isOverTowBallLimit)      // 106 > 100
        #expect(summary.isNoseAboveRecommended)   // 106 > 105
        #expect(!summary.isNoseBelowRecommended)
        #expect(!summary.isOverallSafe)
    }

    @Test("Flags nose weight below the recommended band")
    func belowRecommended() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan(noseWeightBasePercent: 6.0)
        // Rear-biased load drags the nose estimate under the 5% floor (without exceeding MTPLM).
        TestSupport.addLoadedItem(weightKg: 200, zone: .bikeRack, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(summary.isNoseBelowRecommended)
        #expect(!summary.isOverallSafe)
    }

    @Test("Effective tow-ball limit takes the lower of car and hitch caps")
    func effectiveTowBallLimitUsesLowerCap() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan(carMaxTowBallKg: 100, caravanMaxNoseKg: 75)
        TestSupport.addLoadedItem(weightKg: 1, zone: .middle, trip: trip, in: context)

        _ = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(abs(profile.effectiveMaxTowBallKg - 75) < tolerance)
    }

    @Test("A clean, balanced load reports overall safe")
    func balancedLoadIsSafe() throws {
        let (context, profile, trip) = try TestSupport.makeCaravan()
        TestSupport.addLoadedItem(weightKg: 20, zone: .middle, trip: trip, in: context)

        let summary = WeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems ?? [])

        #expect(summary.isOverallSafe)
    }
}
