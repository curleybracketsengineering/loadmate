import Foundation

struct WeightSummary {
    let loadedWeightKg: Double
    let totalWeightKg: Double
    let availableWeightKg: Double
    let mtplmPercent: Double
    /// Nose estimate baseline: configured % of current laden weight (`totalWeightKg`).
    let baseNosePercentKg: Double
    /// Sum of (item mass × zone factor); adjustment from loading locations.
    let locationImpactKg: Double
    let estimatedNoseWeightKg: Double
    let towBallMinKg: Double
    let towBallMaxKg: Double

    let isOverMTPLM: Bool
    /// True when the 5% minimum nose weight meets or exceeds the effective tow ball limit—no compliant loading window.
    let isTowVehicleUnsuitable: Bool
    let isOverTowBallLimit: Bool
    let isNoseBelowRecommended: Bool
    let isNoseAboveRecommended: Bool

    /// True when none of the warning conditions apply (good for a green SAFE banner).
    var isOverallSafe: Bool {
        !isOverMTPLM && !isTowVehicleUnsuitable && !isOverTowBallLimit && !isNoseBelowRecommended && !isNoseAboveRecommended
    }

    /// Progress toward MTPLM as a 0…1 fraction (capped at 1 for bar width even when over limit).
    func mtplmFillFraction(profile: VehicleProfile) -> Double {
        guard profile.mtplmKg > 0 else { return 0 }
        let ratio = totalWeightKg / profile.mtplmKg
        return min(max(ratio, 0), 1)
    }
}

enum WeightCalculator {
    static func zoneFactor(for zone: LoadZone, profile: VehicleProfile) -> Double {
        switch zone.calculationZone(for: profile.kind) {
        case .frontLocker: return profile.factorFrontLocker
        case .front: return profile.factorFront
        case .middle: return profile.factorMiddle
        case .rear: return profile.factorRear
        case .bikeRack: return profile.factorBikeRack
        case .driver, .central, .back, .garage, .unassigned: return 0
        }
    }

    static func summary(
        profile: VehicleProfile,
        loadedItems: [LoadedItem],
        baseNoseOffsetKg: Double = 0
    ) -> WeightSummary {
        let loadedWeight = loadedItems.reduce(0.0) { sum, loaded in
            let weight = loaded.item?.weightKg ?? 0
            return sum + (weight * Double(max(loaded.quantity, 0)))
        }

        let totalWeight = profile.calculationBaseWeightKg + loadedWeight
        let availableWeight = profile.mtplmKg - totalWeight
        let mtplmPercent = profile.mtplmKg > 0 ? (totalWeight / profile.mtplmKg) * 100 : 0

        let locationImpact = loadedItems.reduce(0.0) { sum, loaded in
            let weight = loaded.item?.weightKg ?? 0
            let factor = zoneFactor(for: loaded.zone, profile: profile)
            return sum + (weight * Double(max(loaded.quantity, 0)) * factor)
        }

        let basePercent = profile.noseWeightBasePercent > 0 ? profile.noseWeightBasePercent : 6.0
        let baseNosePercent = totalWeight * (basePercent / 100.0)
        let estimatedNoseWeight = baseNoseOffsetKg + baseNosePercent + locationImpact

        let towBallReferenceWeight = profile.noseSafeZoneReferenceWeightKg(totalLadenWeightKg: totalWeight)
        let towBallMin = towBallReferenceWeight * 0.05
        let towBallMax = towBallReferenceWeight * 0.07
        let effectiveTowBallLimit = profile.effectiveMaxTowBallKg
        let isTowVehicleUnsuitable = effectiveTowBallLimit > 0 && towBallMin >= effectiveTowBallLimit

        return WeightSummary(
            loadedWeightKg: loadedWeight,
            totalWeightKg: totalWeight,
            availableWeightKg: availableWeight,
            mtplmPercent: mtplmPercent,
            baseNosePercentKg: baseNosePercent,
            locationImpactKg: locationImpact,
            estimatedNoseWeightKg: estimatedNoseWeight,
            towBallMinKg: towBallMin,
            towBallMaxKg: towBallMax,
            isOverMTPLM: profile.mtplmKg > 0 && totalWeight > profile.mtplmKg,
            isTowVehicleUnsuitable: isTowVehicleUnsuitable,
            isOverTowBallLimit: effectiveTowBallLimit > 0 && estimatedNoseWeight > effectiveTowBallLimit,
            isNoseBelowRecommended: estimatedNoseWeight < towBallMin,
            isNoseAboveRecommended: estimatedNoseWeight > towBallMax
        )
    }
}
