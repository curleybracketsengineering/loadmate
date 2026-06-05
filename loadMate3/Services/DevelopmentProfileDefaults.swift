import Foundation

#if DEBUG
/// Pre-filled vehicle limits for unit tests and manual QA only — not used on app startup.
/// Values match `docs/manual-testing-script.md`.
enum DevelopmentProfileDefaults {
    static func apply(to profile: VehicleProfile) {
        switch profile.kind {
        case .caravan:
            applyCaravan(to: profile)
        case .motorhome:
            applyMotorhome(to: profile)
        }
    }

    static func applyCaravan(to profile: VehicleProfile) {
        profile.mtplmKg = 1500
        profile.baseWeightKg = 1350
        profile.weighbridgeWeightKg = 1400
        profile.caravanMaxNoseKg = 100
        profile.carMaxTowBallKg = 100
    }

    static func applyMotorhome(to profile: VehicleProfile) {
        profile.mtplmKg = 3500
        profile.baseWeightKg = 3100
        profile.weighbridgeWeightKg = 3100
        profile.weighbridgeFrontAxleKg = 1400
        profile.weighbridgeRearAxleKg = 1700
        profile.maxFrontAxleKg = 1890
        profile.maxRearAxleKg = 2000
        profile.hasBikeRack = true
        profile.maxGarageKg = 150
        profile.usesManualTowBarLoad = true
        profile.maxTowBarKg = 100
    }
}
#endif
