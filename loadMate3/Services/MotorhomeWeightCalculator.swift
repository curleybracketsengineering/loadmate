import Foundation

struct MotorhomeWeightSummary {
    let loadedWeightKg: Double
    let totalWeightKg: Double
    let availableGrossKg: Double
    let baselineFrontAxleKg: Double
    let baselineRearAxleKg: Double
    let frontAxleImpactKg: Double
    let rearAxleImpactKg: Double
    let estimatedFrontAxleKg: Double
    let estimatedRearAxleKg: Double

    /// Trip items counted toward the garage limit (garage zone, plus bike rack when enabled on profile).
    let garageLoadedKg: Double
    let isOverGarageLimit: Bool

    let isOverMAM: Bool
    let isOverFrontAxle: Bool
    let isOverRearAxle: Bool

    let monitorsTowBar: Bool
    let towBarLoadKg: Double
    let isTowBarMeasurementMissing: Bool
    let isOverTowBarLimit: Bool

    var isOverallSafe: Bool {
        !isOverMAM
            && !isOverFrontAxle
            && !isOverRearAxle
            && !isOverGarageLimit
            && !isTowBarMeasurementMissing
            && !isOverTowBarLimit
    }

    func mamFillFraction(profile: VehicleProfile) -> Double {
        guard profile.mtplmKg > 0 else { return 0 }
        return min(max(totalWeightKg / profile.mtplmKg, 0), 1)
    }

    func frontAxleFillFraction(profile: VehicleProfile) -> Double {
        guard profile.maxFrontAxleKg > 0 else { return 0 }
        return min(max(estimatedFrontAxleKg / profile.maxFrontAxleKg, 0), 1)
    }

    func rearAxleFillFraction(profile: VehicleProfile) -> Double {
        guard profile.maxRearAxleKg > 0 else { return 0 }
        return min(max(estimatedRearAxleKg / profile.maxRearAxleKg, 0), 1)
    }

    func garageFillFraction(profile: VehicleProfile) -> Double {
        guard profile.maxGarageKg > 0 else { return 0 }
        return min(max(garageLoadedKg / profile.maxGarageKg, 0), 1)
    }

    func towBarFillFraction(profile: VehicleProfile) -> Double {
        guard profile.maxTowBarKg > 0 else { return 0 }
        return min(max(towBarLoadKg / profile.maxTowBarKg, 0), 1)
    }
}

extension VehicleProfile {
    var monitorsGarageLimit: Bool { kind == .motorhome && maxGarageKg > 0 }

    var monitorsTowBarLimit: Bool { kind == .motorhome && usesManualTowBarLoad && maxTowBarKg > 0 }
}

enum MotorhomeWeightCalculator {
    static func frontRearFactors(for zone: LoadZone, profile: VehicleProfile) -> (front: Double, rear: Double) {
        let z = zone.calculationZone(for: .motorhome)
        switch z {
        case .driver: return (profile.mhFactorDriverFront, profile.mhFactorDriverRear)
        case .front: return (profile.mhFactorCentralFront, profile.mhFactorCentralRear)
        case .central: return (profile.mhFactorCentralFront, profile.mhFactorCentralRear)
        case .back: return (profile.mhFactorBackFront, profile.mhFactorBackRear)
        case .garage: return (profile.mhFactorGarageFront, profile.mhFactorGarageRear)
        case .bikeRack:
            let front = profile.mhFactorBikeRackFront
            let rear = profile.mhFactorBikeRackRear
            if front == 0, rear == 0 {
                return (-0.08, 1.08)
            }
            return (front, rear)
        default: return (0, 0)
        }
    }

    static func garageLoadedMassKg(from loadedItems: [LoadedItem], profile: VehicleProfile) -> Double {
        loadedItems.reduce(0.0) { sum, loaded in
            let zone = loaded.zone
            let countsTowardGarageLimit = zone == .garage
                || (profile.garageLimitIncludesBikeRack && zone == .bikeRack)
            guard countsTowardGarageLimit else { return sum }
            let weight = loaded.item?.weightKg ?? 0
            return sum + (weight * Double(max(loaded.quantity, 0)))
        }
    }

    static func summary(
        profile: VehicleProfile,
        loadedItems: [LoadedItem],
        trip: Trip? = nil
    ) -> MotorhomeWeightSummary {
        let loadedWeight = loadedItems.reduce(0.0) { sum, loaded in
            let weight = loaded.item?.weightKg ?? 0
            return sum + (weight * Double(max(loaded.quantity, 0)))
        }

        let garageLoaded = garageLoadedMassKg(from: loadedItems, profile: profile)

        var frontImpact = 0.0
        var rearImpact = 0.0
        for loaded in loadedItems {
            let mass = (loaded.item?.weightKg ?? 0) * Double(max(loaded.quantity, 0))
            let factors = frontRearFactors(for: loaded.zone, profile: profile)
            frontImpact += mass * factors.front
            rearImpact += mass * factors.rear
        }

        let monitorsTowBar = profile.usesManualTowBarLoad
        let towBarLoad = monitorsTowBar ? max(0, trip?.manualTowBarLoadKg ?? 0) : 0
        let towBarMissing = monitorsTowBar && towBarLoad <= 0
        let overTowBar = profile.maxTowBarKg > 0 && towBarLoad > profile.maxTowBarKg

        // Hitch downforce loads the rear axle and counts toward laden gross mass.
        if towBarLoad > 0 {
            rearImpact += towBarLoad
        }

        var totalWeight = profile.calculationBaseWeightKg + loadedWeight
        if towBarLoad > 0 {
            totalWeight += towBarLoad
        }
        let availableGross = profile.mtplmKg - totalWeight

        let frontBase = profile.baselineFrontAxleKg
        let rearBase = profile.baselineRearAxleKg
        let estimatedFront = frontBase + frontImpact
        let estimatedRear = rearBase + rearImpact

        let overGarage = profile.maxGarageKg > 0 && garageLoaded > profile.maxGarageKg

        return MotorhomeWeightSummary(
            loadedWeightKg: loadedWeight,
            totalWeightKg: totalWeight,
            availableGrossKg: availableGross,
            baselineFrontAxleKg: frontBase,
            baselineRearAxleKg: rearBase,
            frontAxleImpactKg: frontImpact,
            rearAxleImpactKg: rearImpact,
            estimatedFrontAxleKg: estimatedFront,
            estimatedRearAxleKg: estimatedRear,
            garageLoadedKg: garageLoaded,
            isOverGarageLimit: overGarage,
            isOverMAM: profile.mtplmKg > 0 && totalWeight > profile.mtplmKg,
            isOverFrontAxle: profile.maxFrontAxleKg > 0 && estimatedFront > profile.maxFrontAxleKg,
            isOverRearAxle: profile.maxRearAxleKg > 0 && estimatedRear > profile.maxRearAxleKg,
            monitorsTowBar: monitorsTowBar,
            towBarLoadKg: towBarLoad,
            isTowBarMeasurementMissing: towBarMissing,
            isOverTowBarLimit: !towBarMissing && overTowBar
        )
    }
}
