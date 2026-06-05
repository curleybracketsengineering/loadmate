import Testing
import SwiftData
@testable import loadMate3

@MainActor
@Suite("Motorhome weight calculator")
struct MotorhomeWeightCalculatorTests {
    private let tolerance = 0.0001

    @Test("Axle baselines split the base mass by the configured front percentage")
    func axleBaselinesFromSplit() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome(baseWeightKg: 3000, axleSplitFrontPercent: 45)
        TestSupport.addLoadedItem(weightKg: 1, zone: .central, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(abs(summary.baselineFrontAxleKg - 1350) < tolerance)
        #expect(abs(summary.baselineRearAxleKg - 1650) < tolerance)
    }

    @Test("Garage load mostly loads the rear axle")
    func garageLoadsRearAxle() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome()
        TestSupport.addLoadedItem(weightKg: 100, zone: .garage, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        // garage factors: front 0.02, rear 0.98
        #expect(abs(summary.frontAxleImpactKg - 2) < tolerance)
        #expect(abs(summary.rearAxleImpactKg - 98) < tolerance)
        #expect(abs(summary.estimatedFrontAxleKg - 1352) < tolerance)
        #expect(abs(summary.estimatedRearAxleKg - 1748) < tolerance)
    }

    @Test("Total and available gross account for loaded mass")
    func totalsAndGrossHeadroom() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome(mamKg: 3500)
        TestSupport.addLoadedItem(weightKg: 100, zone: .garage, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(abs(summary.totalWeightKg - 3100) < tolerance)
        #expect(abs(summary.availableGrossKg - 400) < tolerance)
    }

    @Test("Garage limit only counts garage zone unless bike rack is included")
    func garageLimitMembership() throws {
        // Bike rack NOT counted toward garage by default.
        let (ctxA, profileA, tripA) = try TestSupport.makeMotorhome(maxGarageKg: 150, hasBikeRack: true)
        TestSupport.addLoadedItem(weightKg: 40, zone: .garage, trip: tripA, in: ctxA)
        TestSupport.addLoadedItem(weightKg: 30, zone: .bikeRack, trip: tripA, in: ctxA)
        let a = MotorhomeWeightCalculator.summary(profile: profileA, loadedItems: tripA.loadedItems, trip: tripA)
        #expect(abs(a.garageLoadedKg - 40) < tolerance)
        #expect(!a.isOverGarageLimit)

        // Bike rack counted when the profile says the rear limit is combined.
        let (ctxB, profileB, tripB) = try TestSupport.makeMotorhome(
            maxGarageKg: 60,
            garageLimitIncludesBikeRack: true,
            hasBikeRack: true
        )
        TestSupport.addLoadedItem(weightKg: 40, zone: .garage, trip: tripB, in: ctxB)
        TestSupport.addLoadedItem(weightKg: 30, zone: .bikeRack, trip: tripB, in: ctxB)
        let b = MotorhomeWeightCalculator.summary(profile: profileB, loadedItems: tripB.loadedItems, trip: tripB)
        #expect(abs(b.garageLoadedKg - 70) < tolerance)
        #expect(b.isOverGarageLimit) // 70 > 60
    }

    @Test("Tow bar load adds to rear axle and gross, and is monitored against its limit")
    func towBarLoad() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome(
            usesManualTowBarLoad: true,
            maxTowBarKg: 100
        )
        trip.manualTowBarLoadKg = 80
        TestSupport.addLoadedItem(weightKg: 100, zone: .central, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(summary.monitorsTowBar)
        #expect(abs(summary.towBarLoadKg - 80) < tolerance)
        #expect(!summary.isTowBarMeasurementMissing)
        #expect(!summary.isOverTowBarLimit) // 80 <= 100
        // central factors are 0.5 / 0.5 -> rear impact = 50, plus 80 tow bar downforce
        #expect(abs(summary.rearAxleImpactKg - 130) < tolerance)
        // base 3000 + 100 loaded + 80 tow bar
        #expect(abs(summary.totalWeightKg - 3180) < tolerance)
    }

    @Test("Missing tow bar measurement is flagged when the motorhome tows")
    func towBarMeasurementMissing() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome(
            usesManualTowBarLoad: true,
            maxTowBarKg: 100
        )
        // No manualTowBarLoadKg entered.
        TestSupport.addLoadedItem(weightKg: 10, zone: .central, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(summary.isTowBarMeasurementMissing)
        #expect(!summary.isOverallSafe)
    }

    @Test("Over tow bar limit is flagged")
    func overTowBarLimit() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome(
            usesManualTowBarLoad: true,
            maxTowBarKg: 100
        )
        trip.manualTowBarLoadKg = 130
        TestSupport.addLoadedItem(weightKg: 10, zone: .central, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(summary.isOverTowBarLimit)
        #expect(!summary.isOverallSafe)
    }

    @Test("Flags over front axle, rear axle and MAM")
    func axleAndMamLimits() throws {
        // Tight limits so a modest load trips them.
        let (context, profile, trip) = try TestSupport.makeMotorhome(
            baseWeightKg: 3400,
            mamKg: 3450,
            maxFrontAxleKg: 1540,
            maxRearAxleKg: 1900
        )
        TestSupport.addLoadedItem(weightKg: 200, zone: .garage, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(summary.isOverMAM)       // 3600 > 3450
        #expect(summary.isOverRearAxle)  // 1870 baseline + 196 impact = 2066 > 1900
        #expect(!summary.isOverallSafe)
    }

    @Test("A within-limits motorhome load reports overall safe")
    func balancedMotorhomeIsSafe() throws {
        let (context, profile, trip) = try TestSupport.makeMotorhome()
        TestSupport.addLoadedItem(weightKg: 50, zone: .central, trip: trip, in: context)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: trip.loadedItems, trip: trip)

        #expect(summary.isOverallSafe)
    }
}
