import Foundation

struct WeightSummary {
    let loadedWeightKg: Double
    let totalWeightKg: Double
    let availableWeightKg: Double
    let mtplmPercent: Double
    /// Nose estimate baseline: 6% of current laden weight (`totalWeightKg`).
    let baseNoseSixPercentKg: Double
    /// Sum of (item mass × zone factor); adjustment from loading locations.
    let locationImpactKg: Double
    let estimatedNoseWeightKg: Double
    let towBallMinKg: Double
    let towBallMaxKg: Double

    let isOverMTPLM: Bool
    let isOverTowBallLimit: Bool
    let isNoseBelowRecommended: Bool
    let isNoseAboveRecommended: Bool

    /// True when none of the warning conditions apply (good for a green SAFE banner).
    var isOverallSafe: Bool {
        !isOverMTPLM && !isOverTowBallLimit && !isNoseBelowRecommended && !isNoseAboveRecommended
    }

    /// Progress toward MTPLM as a 0…1 fraction (capped at 1 for bar width even when over limit).
    func mtplmFillFraction(config: SetupConfig) -> Double {
        guard config.mtplmKg > 0 else { return 0 }
        let ratio = totalWeightKg / config.mtplmKg
        return min(max(ratio, 0), 1)
    }
}

enum WeightCalculator {
    static func zoneFactor(for zone: LoadZone, config: SetupConfig) -> Double {
        switch zone {
        case .frontLocker: return config.factorFrontLocker
        case .front: return config.factorFront
        case .middle: return config.factorMiddle
        case .rear: return config.factorRear
        case .bikeRack: return config.factorBikeRack
        case .unassigned: return 0
        }
    }

    static func summary(
        config: SetupConfig,
        loadedItems: [LoadedItem],
        baseNoseOffsetKg: Double = 0
    ) -> WeightSummary {
        let loadedWeight = loadedItems.reduce(0.0) { sum, loaded in
            let weight = loaded.item?.weightKg ?? 0
            return sum + (weight * Double(max(loaded.quantity, 0)))
        }

        let totalWeight = config.baseWeightKg + loadedWeight
        let availableWeight = config.mtplmKg - totalWeight
        let mtplmPercent = config.mtplmKg > 0 ? (totalWeight / config.mtplmKg) * 100 : 0

        let locationImpact = loadedItems.reduce(0.0) { sum, loaded in
            let weight = loaded.item?.weightKg ?? 0
            let factor = zoneFactor(for: loaded.zone, config: config)
            return sum + (weight * Double(max(loaded.quantity, 0)) * factor)
        }

        let baseNoseSixPercent = totalWeight * 0.06
        let estimatedNoseWeight = baseNoseOffsetKg + baseNoseSixPercent + locationImpact

        let towBallReferenceWeight = config.mtplmKg > 0 ? min(totalWeight, config.mtplmKg) : totalWeight
        let towBallMin = towBallReferenceWeight * 0.05
        let towBallMax = towBallReferenceWeight * 0.07

        return WeightSummary(
            loadedWeightKg: loadedWeight,
            totalWeightKg: totalWeight,
            availableWeightKg: availableWeight,
            mtplmPercent: mtplmPercent,
            baseNoseSixPercentKg: baseNoseSixPercent,
            locationImpactKg: locationImpact,
            estimatedNoseWeightKg: estimatedNoseWeight,
            towBallMinKg: towBallMin,
            towBallMaxKg: towBallMax,
            isOverMTPLM: config.mtplmKg > 0 && totalWeight > config.mtplmKg,
            isOverTowBallLimit: config.carMaxTowBallKg > 0 && estimatedNoseWeight > config.carMaxTowBallKg,
            isNoseBelowRecommended: estimatedNoseWeight < towBallMin,
            isNoseAboveRecommended: estimatedNoseWeight > towBallMax
        )
    }
}
