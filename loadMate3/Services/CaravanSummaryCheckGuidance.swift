import Foundation

struct CaravanSummaryCheck: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let isPositive: Bool
    let whyItMatters: String
    let actionSteps: [String]

    static func build(
        summary: WeightSummary,
        profile: VehicleProfile,
        loadedItems: [LoadedItem]
    ) -> [CaravanSummaryCheck] {
        let payloadLimit = max(0, profile.mtplmKg - profile.calculationBaseWeightKg)
        let frontKg = zoneWeight(in: [.frontLocker, .front], items: loadedItems)
        let rearKg = zoneWeight(in: [.rear, .bikeRack], items: loadedItems)
        let mostlyForward = frontKg > rearKg && frontKg > 0
        let noseInRange = !summary.isNoseBelowRecommended
            && !summary.isNoseAboveRecommended
            && !summary.isTowVehicleUnsuitable

        let towbarPositive = !summary.isOverTowBallLimit && !summary.isTowVehicleUnsuitable
        let payloadPositive = payloadLimit <= 0 || summary.loadedWeightKg <= payloadLimit

        return [
            towbarCheck(summary: summary, profile: profile, isPositive: towbarPositive),
            mtplmCheck(summary: summary, profile: profile),
            payloadCheck(summary: summary, payloadLimit: payloadLimit, isPositive: payloadPositive),
            noseCheck(summary: summary, profile: profile, isPositive: noseInRange),
            balanceCheck(mostlyForward: mostlyForward, isPositive: !mostlyForward),
        ]
    }

    // MARK: - Individual checks

    private static func towbarCheck(
        summary: WeightSummary,
        profile: VehicleProfile,
        isPositive: Bool
    ) -> CaravanSummaryCheck {
        let limit = profile.effectiveMaxTowBallKg
        let overBy = max(0, summary.estimatedNoseWeightKg - limit)

        var steps: [String] = []
        if summary.isTowVehicleUnsuitable {
            steps = [
                "The 5% minimum nose weight meets or exceeds your tow ball limit — this outfit may not be legally compliant.",
                "Use a car with a higher tow ball limit, a lighter caravan, or confirm hitch ratings with your manufacturer.",
                "Always confirm actual nose weight on a gauge before towing.",
            ]
        } else if summary.isOverTowBallLimit {
            steps = [
                "Do not tow until nose weight is at or below your limit on a physical gauge.",
                "Move heavy items from the front locker and forward areas toward the middle and rear.",
                "Remove non-essentials (water, tools, bikes) if still over the limit.",
                overBy > 0
                    ? "Aim to reduce estimated nose weight by about \(kgPhrase(overBy))."
                    : "Re-check with a nose weight gauge at hitch height.",
            ]
        } else {
            steps = [
                "Confirm nose weight with a gauge before every trip — last-minute packing changes it quickly.",
                "Keep heavy items low and near the axle; use the front locker for light kit where possible.",
                "Re-check after filling water tanks or loading the awning.",
            ]
        }

        return CaravanSummaryCheck(
            id: "towbar",
            title: "Towbar weight",
            message: isPositive
                ? "Towbar weight is within the limit"
                : "Towbar weight exceeds your limit",
            isPositive: isPositive,
            whyItMatters: """
            Weight on the tow ball loads the car’s rear axle, tow bar, and hitch. Too much reduces front-axle grip, stresses the coupling, and can make the outfit harder to control. This is a hard limit from your car and caravan plates — not just a comfort band.
            """,
            actionSteps: steps
        )
    }

    private static func mtplmCheck(summary: WeightSummary, profile: VehicleProfile) -> CaravanSummaryCheck {
        let isPositive = !summary.isOverMTPLM
        let overBy = max(0, summary.totalWeightKg - profile.mtplmKg)

        let steps: [String]
        if summary.isOverMTPLM {
            steps = [
                "Reduce total laden weight — moving items around does not fix an MTPLM breach.",
                overBy > 0 ? "Remove at least \(kgPhrase(overBy)) of load." : "Remove items until under your plate MTPLM.",
                "Visit a weighbridge to confirm base and total mass.",
                "Check tyres and pressures for the actual laden weight.",
            ]
        } else {
            steps = [
                "Leave headroom below MTPLM for water, shopping, and measurement error.",
                "Update weighbridge weight in Settings when you have a fresh reading.",
                "Re-check the summary after filling tanks or adding last-minute kit.",
            ]
        }

        return CaravanSummaryCheck(
            id: "mtplm",
            title: "Caravan weight",
            message: isPositive
                ? "Caravan weight is within MTPLM"
                : "Caravan weight exceeds MTPLM",
            isPositive: isPositive,
            whyItMatters: """
            MTPLM is the maximum laden mass on your caravan plate. Exceeding it puts tyres, brakes, and the chassis outside their design limits and can affect insurance and compliance.
            """,
            actionSteps: steps
        )
    }

    private static func payloadCheck(
        summary: WeightSummary,
        payloadLimit: Double,
        isPositive: Bool
    ) -> CaravanSummaryCheck {
        let overBy = max(0, summary.loadedWeightKg - payloadLimit)

        let steps: [String]
        if !isPositive && payloadLimit > 0 {
            steps = [
                "Reduce trip items — start with water, duplicates, and heavy optional kit.",
                overBy > 0 ? "Remove about \(kgPhrase(overBy)) from your load list." : "Remove items until payload is within limit.",
                "Weigh bulky items (awnings, batteries, BBQs) rather than guessing.",
            ]
        } else {
            steps = [
                "Payload is room for trip kit on top of your base (MIRO or weighbridge) weight.",
                "Log heavy items in Lyneqo Caravan & Motorhome and assign them to locations on the map.",
                "Full fresh or grey water can use much of your payload — plan tank levels for travel.",
            ]
        }

        return CaravanSummaryCheck(
            id: "payload",
            title: "Payload",
            message: isPositive
                ? "Payload is within your limit"
                : "Payload exceeds your available limit",
            isPositive: isPositive,
            whyItMatters: """
            Payload is how much you can add before the caravan reaches MTPLM. Overloading increases nose weight, axle stress, and braking distance, and leaves no margin for extras on the road.
            """,
            actionSteps: steps
        )
    }

    private static func noseCheck(
        summary: WeightSummary,
        profile: VehicleProfile,
        isPositive: Bool
    ) -> CaravanSummaryCheck {
        var steps: [String] = []
        if summary.isTowVehicleUnsuitable {
            steps = [
                "Resolve tow ball suitability in Settings before tuning nose weight.",
                "Confirm car tow ball and caravan hitch limits match your handbooks.",
            ]
        } else if summary.isNoseBelowRecommended {
            let increaseBy = max(0, summary.towBallMinKg - summary.estimatedNoseWeightKg)
            steps = [
                increaseBy > 0
                    ? "Increase nose weight by about \(kgPhrase(increaseBy)) if possible."
                    : "Move heavier items forward, kept low in lockers — not high in overhead cupboards.",
                "Ensure the hitch is fully seated and the caravan is level when gauging.",
                "Too little nose weight increases sway risk — verify on a gauge.",
            ]
        } else if summary.isNoseAboveRecommended {
            let reduceBy = max(0, summary.estimatedNoseWeightKg - summary.towBallMaxKg)
            steps = [
                reduceBy > 0
                    ? "Reduce nose weight by about \(kgPhrase(reduceBy)) toward the 5–7% band."
                    : "Move heavy items rearward toward the axle and rear storage.",
                "Empty or lighten the front locker first.",
                "Confirm with a nose weight gauge; stay within your tow ball limit as well.",
            ]
        } else {
            steps = [
                "Stay within the 5–7% recommended band where possible — it supports stable towing.",
                "Always verify with a nose weight gauge; Lyneqo Caravan & Motorhome figures are estimates.",
                "Re-check after changing load locations or filling water.",
            ]
        }

        return CaravanSummaryCheck(
            id: "nose",
            title: "Nose weight",
            message: isPositive
                ? "Nose weight is in the recommended range"
                : "Nose weight is outside the recommended range",
            isPositive: isPositive,
            whyItMatters: """
            Many manufacturers and clubs recommend roughly 5–7% of laden caravan weight on the hitch. Too low can cause unstable towing; too high overloads the tow ball and can lift the car’s front end, affecting steering and braking.
            """,
            actionSteps: steps
        )
    }

    private static func balanceCheck(mostlyForward: Bool, isPositive: Bool) -> CaravanSummaryCheck {
        let steps: [String]
        if mostlyForward {
            steps = [
                "Move the heaviest items from the front locker and forward zones to the middle (over the axle) first.",
                "Use the rear for moderate weight only if nose weight is still high enough.",
                "Keep dense kit low, not in high overhead lockers.",
                "Avoid heavy loads on the bike rack unless the manufacturer allows it and nose weight is confirmed.",
            ]
        } else {
            steps = [
                "Keep the heaviest mass low and near the axle.",
                "Balance left and right where you can — uneven side loading affects stability.",
                "Review placement on the Locations map after major repacks.",
            ]
        }

        return CaravanSummaryCheck(
            id: "balance",
            title: "Load distribution",
            message: isPositive
                ? "Load is spread across the caravan"
                : "Heavy items are mostly forward",
            isPositive: isPositive,
            whyItMatters: """
            Front-heavy loading pushes weight onto the tow ball and can trigger nose-weight and tow-bar warnings. Heavier kit is generally safer low and near the axle, with only light items far forward unless you deliberately need more nose weight.
            """,
            actionSteps: steps
        )
    }

    // MARK: - Helpers

    private static func zoneWeight(in zones: [LoadZone], items: [LoadedItem]) -> Double {
        items.reduce(0) { sum, loaded in
            guard zones.contains(loaded.zone) else { return sum }
            let weight = loaded.item?.weightKg ?? 0
            return sum + weight * Double(max(loaded.quantity, 0))
        }
    }

    private static func kgPhrase(_ kg: Double) -> String {
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: kg))
            ?? String(format: "%.1f", kg)
        let trimmed = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        return "\(trimmed) kg"
    }
}
