import Foundation

struct MotorhomeSummaryCheck: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let isPositive: Bool
    let whyItMatters: String
    let actionSteps: [String]

    static func build(
        summary: MotorhomeWeightSummary,
        profile: VehicleProfile
    ) -> [MotorhomeSummaryCheck] {
        let payloadLimit = max(0, profile.mtplmKg - profile.calculationBaseWeightKg)

        var checks: [MotorhomeSummaryCheck] = [
            frontAxleCheck(summary: summary, profile: profile),
            rearAxleCheck(summary: summary, profile: profile),
        ]

        if profile.monitorsGarageLimit {
            checks.append(garageCheck(summary: summary, profile: profile))
        }

        if summary.monitorsTowBar {
            checks.append(towBarCheck(summary: summary, profile: profile))
        }

        checks.append(payloadCheck(summary: summary, payloadLimit: payloadLimit))

        return checks
    }

    // MARK: - Individual checks

    private static func frontAxleCheck(
        summary: MotorhomeWeightSummary,
        profile: VehicleProfile
    ) -> MotorhomeSummaryCheck {
        let isPositive = !summary.isOverFrontAxle
        let overBy = max(0, summary.estimatedFrontAxleKg - profile.maxFrontAxleKg)

        let steps: [String]
        if summary.isOverFrontAxle {
            steps = [
                "Do not travel until front axle load is confirmed on a weighbridge.",
                "Move heavy items from the cab and forward lockers toward the central living area.",
                overBy > 0
                    ? "Aim to reduce front axle load by about \(kgPhrase(overBy))."
                    : "Re-check axle weights after repacking.",
                "Update baseline axle weights in Settings when you have fresh weighbridge readings.",
            ]
        } else {
            steps = [
                "Keep dense kit low and avoid stacking heavy items high in overhead lockers near the cab.",
                "Re-check after adding passengers, bikes, or a full fresh-water tank.",
                "Confirm with a weighbridge before long trips — Lyneqo Caravan & Motorhome figures are estimates.",
            ]
        }

        return MotorhomeSummaryCheck(
            id: "front",
            title: "Front axle",
            message: isPositive
                ? "Front axle load is within the limit"
                : "Front axle load exceeds the limit",
            isPositive: isPositive,
            whyItMatters: """
            The front axle carries steering and braking loads. Exceeding its limit can affect grip, tyre wear, and compliance with your vehicle plate. Lyneqo Caravan & Motorhome estimates axle load from your weighbridge baseline plus where items are placed in the motorhome.
            """,
            actionSteps: steps
        )
    }

    private static func rearAxleCheck(
        summary: MotorhomeWeightSummary,
        profile: VehicleProfile
    ) -> MotorhomeSummaryCheck {
        let isPositive = !summary.isOverRearAxle
        let overBy = max(0, summary.estimatedRearAxleKg - profile.maxRearAxleKg)

        let steps: [String]
        if summary.isOverRearAxle {
            steps = [
                "Reduce rear axle load before travelling — moving items sideways does not fix an axle breach.",
                "Move heavy kit from the rear garage and bike rack toward the central zones.",
                overBy > 0
                    ? "Aim to reduce rear axle load by about \(kgPhrase(overBy))."
                    : "Visit a weighbridge to confirm actual axle masses.",
                "Check tyre pressures for the laden weight shown on your plate.",
            ]
        } else {
            steps = [
                "Spread weight evenly left and right where you can.",
                "Heavy rear loads (bikes, scooters, awnings) have a strong effect — log them in Lyneqo Caravan & Motorhome.",
                "Leave margin below the limit for fuel, water, and last-minute kit.",
            ]
        }

        return MotorhomeSummaryCheck(
            id: "rear",
            title: "Rear axle",
            message: isPositive
                ? "Rear axle load is within the limit"
                : "Rear axle load exceeds the limit",
            isPositive: isPositive,
            whyItMatters: """
            The rear axle often carries garage, bike rack, and rear locker weight. Overloading it stresses tyres, suspension, and the chassis. It also affects how the motorhome handles on hills and when braking.
            """,
            actionSteps: steps
        )
    }

    private static func garageCheck(
        summary: MotorhomeWeightSummary,
        profile: VehicleProfile
    ) -> MotorhomeSummaryCheck {
        let isPositive = !summary.isOverGarageLimit
        let overBy = max(0, summary.garageLoadedKg - profile.maxGarageKg)

        let steps: [String]
        if summary.isOverGarageLimit {
            steps = [
                "Remove or relocate items from the garage (and bike rack if it counts toward this limit).",
                overBy > 0
                    ? "Reduce garage-zone load by about \(kgPhrase(overBy))."
                    : "Check manufacturer guidance for maximum garage and rack loading.",
                "Store heavy tools and spare wheels in a central zone if axle limits allow.",
            ]
        } else {
            steps = [
                "Garage limits protect the rear structure and floor — stay below your handbook figure.",
                "Distribute heavy items low and secure them for travel.",
                "If your limit includes the bike rack, log rack items separately on the Locations map.",
            ]
        }

        return MotorhomeSummaryCheck(
            id: "garage",
            title: "Garage load",
            message: isPositive
                ? "Garage load is within the limit"
                : "Garage load exceeds the limit",
            isPositive: isPositive,
            whyItMatters: """
            Many motorhomes have a maximum mass for the rear garage (and sometimes the bike rack). Exceeding it can overload the rear axle and damage storage fittings. This check uses items you placed in garage and rack zones.
            """,
            actionSteps: steps
        )
    }

    private static func towBarCheck(
        summary: MotorhomeWeightSummary,
        profile: VehicleProfile
    ) -> MotorhomeSummaryCheck {
        let isPositive = !summary.isOverTowBarLimit && !summary.isTowBarMeasurementMissing
        let overBy = max(0, summary.towBarLoadKg - profile.maxTowBarKg)

        var steps: [String] = []
        if summary.isTowBarMeasurementMissing {
            steps = [
                "Enter your measured tow bar load in Settings or on the Summary screen.",
                "Use a calibrated gauge at hitch height with the outfit level.",
                "Lyneqo Caravan & Motorhome cannot verify the limit until a value is recorded.",
            ]
        } else if summary.isOverTowBarLimit {
            steps = [
                "Do not tow until tow bar load is at or below your limit on a physical gauge.",
                "Move heavy items from the rear of the motorhome or trailer toward the axle.",
                overBy > 0
                    ? "Aim to reduce tow bar load by about \(kgPhrase(overBy))."
                    : "Re-check with a gauge after repacking.",
                "Confirm hitch, tow bar, and trailer nose-weight limits in your handbooks.",
            ]
        } else {
            steps = [
                "Confirm tow bar load with a gauge before every trip.",
                "Re-check after loading the trailer or changing rear storage.",
                "Keep within both tow bar and trailer nose-weight limits.",
            ]
        }

        return MotorhomeSummaryCheck(
            id: "towbar",
            title: "Tow bar load",
            message: isPositive
                ? "Tow bar load is within the limit"
                : "Tow bar load is not within the limit",
            isPositive: isPositive,
            whyItMatters: """
            Weight on the tow bar loads the motorhome rear axle and the hitch assembly. Too much reduces stability, stresses the coupling, and can exceed the limits on your tow bar and trailer plate.
            """,
            actionSteps: steps
        )
    }

    private static func payloadCheck(
        summary: MotorhomeWeightSummary,
        payloadLimit: Double
    ) -> MotorhomeSummaryCheck {
        let isPositive = !summary.isOverMAM
        let overBy = max(0, summary.loadedWeightKg - payloadLimit)

        let steps: [String]
        if summary.isOverMAM {
            steps = [
                "Reduce trip items — redistributing load does not fix an overall mass (MAM) breach.",
                overBy > 0 && payloadLimit > 0
                    ? "Remove at least \(kgPhrase(overBy)) from your load list."
                    : "Remove items until total laden mass is within MAM.",
                "Visit a weighbridge to confirm base and laden weight.",
                "Check tyres and pressures for the actual laden mass.",
            ]
        } else {
            steps = [
                "Payload is the room left for kit on top of your base (MIRO or weighbridge) weight.",
                "Log heavy items in Lyneqo Caravan & Motorhome and assign them to locations on the map.",
                "Full fresh or grey water can use much of your payload — plan tank levels for travel.",
            ]
        }

        return MotorhomeSummaryCheck(
            id: "payload",
            title: "Payload",
            message: isPositive
                ? "Payload is within your limit"
                : "Payload exceeds your available limit",
            isPositive: isPositive,
            whyItMatters: """
            Payload is how much you can add before the motorhome reaches Maximum Authorised Mass (MAM). Overloading affects braking, handling, and insurance, and leaves no margin for fuel, water, and extras on the road.
            """,
            actionSteps: steps
        )
    }

    // MARK: - Helpers

    private static func kgPhrase(_ kg: Double) -> String {
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: kg))
            ?? String(format: "%.1f", kg)
        let trimmed = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        return "\(trimmed) kg"
    }
}
