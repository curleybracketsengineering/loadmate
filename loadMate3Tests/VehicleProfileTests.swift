import Testing
@testable import loadMate3

@Suite("VehicleProfile derived values")
struct VehicleProfileTests {
    private let tolerance = 0.0001

    @Test("Calculation base weight prefers weighbridge over manufacturer base")
    func calculationBaseWeightPrefersWeighbridge() {
        let profile = VehicleProfile(kind: .caravan)
        profile.baseWeightKg = 1250
        profile.weighbridgeWeightKg = 0
        #expect(abs(profile.calculationBaseWeightKg - 1250) < tolerance)

        profile.weighbridgeWeightKg = 1300
        #expect(abs(profile.calculationBaseWeightKg - 1300) < tolerance)
    }

    @Test("Effective tow-ball limit is the lowest positive cap")
    func effectiveTowBallLimit() {
        let profile = VehicleProfile(kind: .caravan)
        profile.carMaxTowBallKg = 100
        profile.caravanMaxNoseKg = 0
        #expect(abs(profile.effectiveMaxTowBallKg - 100) < tolerance)

        profile.caravanMaxNoseKg = 75
        #expect(abs(profile.effectiveMaxTowBallKg - 75) < tolerance)

        profile.carMaxTowBallKg = 0
        profile.caravanMaxNoseKg = 0
        #expect(abs(profile.effectiveMaxTowBallKg - 0) < tolerance)
    }

    @Test("Nose safe-zone reference uses MTPLM or laden weight per basis")
    func noseSafeZoneReference() {
        let profile = VehicleProfile(kind: .caravan)
        profile.mtplmKg = 1500

        profile.noseSafeZoneBasis = .mtplm
        #expect(abs(profile.noseSafeZoneReferenceWeightKg(totalLadenWeightKg: 1350) - 1500) < tolerance)

        profile.noseSafeZoneBasis = .ladenWeight
        #expect(abs(profile.noseSafeZoneReferenceWeightKg(totalLadenWeightKg: 1350) - 1350) < tolerance)

        // MTPLM basis falls back to laden weight when MTPLM is unset.
        profile.noseSafeZoneBasis = .mtplm
        profile.mtplmKg = 0
        #expect(abs(profile.noseSafeZoneReferenceWeightKg(totalLadenWeightKg: 1350) - 1350) < tolerance)
    }

    @Test("Configured-for-calculations gate differs by vehicle kind")
    func isConfiguredForWeightCalculations() {
        let caravan = VehicleProfile(kind: .caravan)
        caravan.weighbridgeWeightKg = 1300
        caravan.mtplmKg = 1500
        caravan.carMaxTowBallKg = 100
        #expect(caravan.isConfiguredForWeightCalculations)

        caravan.carMaxTowBallKg = 0
        #expect(!caravan.isConfiguredForWeightCalculations)

        let motorhome = VehicleProfile(kind: .motorhome)
        motorhome.weighbridgeWeightKg = 3000
        motorhome.mtplmKg = 3500
        motorhome.maxFrontAxleKg = 1600
        motorhome.maxRearAxleKg = 2000
        #expect(motorhome.isConfiguredForWeightCalculations)

        motorhome.maxRearAxleKg = 0
        #expect(!motorhome.isConfiguredForWeightCalculations)
    }

    @Test("Gross mass label matches the vehicle kind")
    func grossMassLabel() {
        #expect(VehicleProfile(kind: .caravan).grossMassLabel == "MTPLM")
        #expect(VehicleProfile(kind: .motorhome).grossMassLabel == "MAM")
    }

    @Test("Pad cutaway asset name reflects tow bar and bike rack configuration")
    func padCutawayAssetName() {
        let caravan = VehicleProfile(kind: .caravan)
        caravan.hasBikeRack = false
        #expect(caravan.padCutawayAssetName == "Caravan")
        caravan.hasBikeRack = true
        #expect(caravan.padCutawayAssetName == "caravanAndBike")

        let motorhome = VehicleProfile(kind: .motorhome)
        motorhome.usesManualTowBarLoad = false
        motorhome.hasBikeRack = false
        #expect(motorhome.padCutawayAssetName == "Motorhome")
        motorhome.hasBikeRack = true
        #expect(motorhome.padCutawayAssetName == "MotorhomeBike")
        motorhome.usesManualTowBarLoad = true
        motorhome.hasBikeRack = false
        #expect(motorhome.padCutawayAssetName == "MotorhomeTow")
        motorhome.hasBikeRack = true
        #expect(motorhome.padCutawayAssetName == "MotorhomeTowBike")
    }

    @Test("Pad zone order drops the bike rack zone when no rack is fitted")
    func padZoneDisplayOrder() {
        let caravan = VehicleProfile(kind: .caravan)
        caravan.hasBikeRack = false
        #expect(!caravan.padZoneDisplayOrder.contains(.bikeRack))
        caravan.hasBikeRack = true
        #expect(caravan.padZoneDisplayOrder.contains(.bikeRack))

        let motorhome = VehicleProfile(kind: .motorhome)
        motorhome.hasBikeRack = false
        #expect(!motorhome.padZoneDisplayOrder.contains(.bikeRack))
        #expect(motorhome.padZoneDisplayOrder == [.driver, .central, .back, .garage])
    }
}
