import Foundation

/// Cross-checks motorhome weighbridge gross vs per-axle ticket weights.
enum MotorhomeWeighbridgeValidation {
    /// Allowed difference (kg) when comparing axle sum to gross from the same visit.
    static let matchToleranceKg: Double = 10

    struct Issue: Equatable {
        let message: String
    }

    struct Result: Equatable {
        let issues: [Issue]

        var isConsistent: Bool { issues.isEmpty }

        /// Single line for summary banners.
        var bannerMessage: String? {
            issues.first?.message
        }

        /// All messages for Settings (may show multiple).
        var allMessages: [String] { issues.map(\.message) }
    }

    static func validate(profile: VehicleProfile) -> Result {
        guard profile.kind == .motorhome else { return Result(issues: []) }

        var issues: [Issue] = []
        let gross = profile.weighbridgeWeightKg
        let front = profile.weighbridgeFrontAxleKg
        let rear = profile.weighbridgeRearAxleKg
        let axleSum = front + rear
        let mam = profile.mtplmKg

        if mam > 0, gross > mam {
            issues.append(
                Issue(
                    message: "Weighbridge gross (\(formatKg(gross))) exceeds MAM (\(formatKg(mam))). Check your plate limit."
                )
            )
        }

        if mam > 0, axleSum > mam {
            issues.append(
                Issue(
                    message: "Front and rear axle weights total \(formatKg(axleSum)), which exceeds MAM (\(formatKg(mam)))."
                )
            )
        }

        guard gross > 0, axleSum > 0 else {
            return Result(issues: issues)
        }

        let delta = axleSum - gross

        if delta > matchToleranceKg {
            issues.append(
                Issue(
                    message: "Front and rear axle weights total \(formatKg(axleSum)), which is more than weighbridge gross (\(formatKg(gross))). They must be from the same reading — correct Settings or the app uses gross for weight totals until they match."
                )
            )
        } else if front > 0, rear > 0, gross - axleSum > matchToleranceKg {
            issues.append(
                Issue(
                    message: "Front and rear axle weights total \(formatKg(axleSum)) but weighbridge gross is \(formatKg(gross)). On one ticket these should match — check both figures."
                )
            )
        } else if abs(delta) > matchToleranceKg {
            issues.append(
                Issue(
                    message: "Axle weights (\(formatKg(axleSum))) and weighbridge gross (\(formatKg(gross))) differ by \(formatKg(abs(delta))). They should match the same weighbridge visit."
                )
            )
        }

        return Result(issues: issues)
    }

    /// True when gross and axle sum are both entered and agree within tolerance.
    static func axleWeightsMatchGross(axleSum: Double, gross: Double) -> Bool {
        guard gross > 0, axleSum > 0 else { return false }
        return abs(axleSum - gross) <= matchToleranceKg
    }

    /// Prefer axle sum only when it matches gross; otherwise gross wins when both are set.
    static func shouldUseAxleSumForBaseWeight(profile: VehicleProfile) -> Bool {
        guard profile.kind == .motorhome else { return false }
        let axleSum = profile.weighbridgeFrontAxleKg + profile.weighbridgeRearAxleKg
        guard axleSum > 0 else { return false }
        let gross = profile.weighbridgeWeightKg
        guard gross > 0 else { return true }
        return axleWeightsMatchGross(axleSum: axleSum, gross: gross)
    }

    private static func formatKg(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded)) kg"
        }
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(formatted) kg"
    }
}

extension VehicleProfile {
    var motorhomeWeighbridgeValidation: MotorhomeWeighbridgeValidation.Result {
        MotorhomeWeighbridgeValidation.validate(profile: self)
    }

    /// Axle ticket lines disagree with gross — per-axle baselines should not drive estimates alone.
    var motorhomeHasConflictingWeighbridgeEntries: Bool {
        guard kind == .motorhome else { return false }
        let axleSum = weighbridgeFrontAxleKg + weighbridgeRearAxleKg
        guard axleSum > 0, weighbridgeWeightKg > 0 else { return false }
        return !MotorhomeWeighbridgeValidation.axleWeightsMatchGross(axleSum: axleSum, gross: weighbridgeWeightKg)
    }
}
