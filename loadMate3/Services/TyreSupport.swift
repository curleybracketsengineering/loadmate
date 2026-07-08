import Foundation

enum PressureUnit: String, CaseIterable, Identifiable {
    case psi
    case bar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .psi: return "PSI"
        case .bar: return "Bar"
        }
    }
}

enum TyreStatusLevel {
    case current
    case attention
    case action
    case incomplete

    var symbolName: String {
        switch self {
        case .current: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .action: return "exclamationmark.circle.fill"
        case .incomplete: return "questionmark.circle.fill"
        }
    }
}

struct TyreAgeAssessment {
    let level: TyreStatusLevel
    let status: String
    let message: String?
}

struct TyrePressureAssessment {
    let level: TyreStatusLevel
    let status: String
    let message: String
}

enum TyreSupport {
    static let tyreDisclaimer = "LoadMate helps you record tyre information and identify items that may need attention. It cannot inspect a tyre or confirm that a tyre is safe for use. Always follow the vehicle, caravan and tyre manufacturer’s instructions. If a tyre is damaged, incorrectly inflated, unusually worn or of uncertain condition, have it inspected by a qualified tyre professional before travelling."

    static let pressureUnitAppStorageKey = "tyrePressureUnitRaw"

    static let psiPerBar = 14.5038
    static let ageApproachingYears = 4
    static let ageReviewYears = 5
    static let caravanStrongReviewYears = 7

    static func normalizedDateCode(from input: String) -> String {
        input.replacingOccurrences(of: "[\\s/-]", with: "", options: .regularExpression)
    }

    static func parseDateCode(_ input: String, now: Date = Date()) -> (normalized: String, week: Int, year: Int, manufactureDate: Date)? {
        let normalized = normalizedDateCode(from: input)
        guard normalized.count == 4, normalized.allSatisfy(\.isNumber) else { return nil }
        guard let week = Int(normalized.prefix(2)), let shortYear = Int(normalized.suffix(2)) else { return nil }
        guard (1...53).contains(week) else { return nil }

        let fullYear = shortYear >= 80 ? 1900 + shortYear : 2000 + shortYear
        guard let date = isoWeekStart(year: fullYear, week: week) else { return nil }
        guard date <= now else { return nil }

        let calendar = Calendar(identifier: .iso8601)
        let dateWeek = calendar.component(.weekOfYear, from: date)
        let dateYear = calendar.component(.yearForWeekOfYear, from: date)
        guard dateWeek == week, dateYear == fullYear else { return nil }

        return (normalized, week, fullYear, date)
    }

    static func isoWeekStart(year: Int, week: Int) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .iso8601)
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = 2
        return components.date
    }

    static func ageText(for manufactureDate: Date?, now: Date = Date()) -> String {
        guard let manufactureDate else { return "Age unknown" }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: manufactureDate, to: now)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)

        if years < 1 {
            let monthText = months == 1 ? "1 month" : "\(months) months"
            return "\(monthText) old"
        }

        let yearText = years == 1 ? "1 year" : "\(years) years"
        if months == 0 {
            return "\(yearText) old"
        }
        let monthText = months == 1 ? "1 month" : "\(months) months"
        return "\(yearText) \(monthText) old"
    }

    static func ageAssessment(for record: TyreRecord, now: Date = Date()) -> TyreAgeAssessment {
        guard let manufactureDate = record.manufactureDate else {
            return TyreAgeAssessment(level: .incomplete, status: "Age unknown", message: "Manufacture date not recorded")
        }

        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: manufactureDate, to: now).year ?? 0

        if record.position.rawValue.hasPrefix("caravan"), years >= caravanStrongReviewYears {
            return TyreAgeAssessment(
                level: .action,
                status: "Replacement strongly recommended",
                message: "Caravan tyres should not normally remain in service beyond seven years, regardless of their apparent tread depth."
            )
        }
        if years >= ageReviewYears {
            return TyreAgeAssessment(
                level: .action,
                status: "Replacement review recommended",
                message: "This tyre is five years old or more. Have its condition and continued suitability assessed and consider replacement."
            )
        }
        if years >= ageApproachingYears {
            return TyreAgeAssessment(
                level: .attention,
                status: "Approaching five years",
                message: "This tyre is approaching the recommended five-year review point."
            )
        }
        return TyreAgeAssessment(level: .current, status: "Current", message: nil)
    }

    static func pressureAssessment(for record: TyreRecord) -> TyrePressureAssessment {
        guard let recommended = record.recommendedPressurePSI, recommended > 0 else {
            return TyrePressureAssessment(level: .incomplete, status: "Pressure target missing", message: "Check against manufacturer information.")
        }
        guard let latest = record.latestPressurePSI else {
            return TyrePressureAssessment(level: .incomplete, status: "No recent pressure reading", message: "No recent pressure reading")
        }

        let delta = (latest - recommended) / recommended
        if delta < -0.10 {
            return TyrePressureAssessment(level: .action, status: "Pressure significantly below target", message: "Pressure significantly below target")
        }
        if delta < -0.05 {
            return TyrePressureAssessment(level: .attention, status: "Pressure slightly below target", message: "Pressure slightly below target")
        }
        if delta > 0.10 {
            return TyrePressureAssessment(level: .attention, status: "Pressure above recorded target", message: "Pressure above recorded target")
        }
        return TyrePressureAssessment(level: .current, status: "Pressure within recorded target", message: "Pressure within recorded target")
    }

    static func convertPressure(_ value: Double, from unit: PressureUnit, to targetUnit: PressureUnit) -> Double {
        guard unit != targetUnit else { return value }
        switch (unit, targetUnit) {
        case (.psi, .bar):
            return value / psiPerBar
        case (.bar, .psi):
            return value * psiPerBar
        default:
            return value
        }
    }

    static func layoutOptions(for kind: VehicleKind) -> [TyreLayout] {
        switch kind {
        case .caravan:
            return [.caravanSingleAxle, .caravanTwinAxle]
        case .motorhome:
            return [.motorhomeFourWheel, .motorhomeSixWheel]
        }
    }

    static func positions(for layout: TyreLayout, includeSpare: Bool) -> [TyrePosition] {
        let positions: [TyrePosition]
        switch layout {
        case .caravanSingleAxle:
            positions = [.caravanLeft, .caravanRight]
        case .caravanTwinAxle:
            positions = [.caravanFrontLeft, .caravanFrontRight, .caravanRearLeft, .caravanRearRight]
        case .motorhomeFourWheel:
            positions = [.motorhomeFrontLeft, .motorhomeFrontRight, .motorhomeRearLeft, .motorhomeRearRight]
        case .motorhomeSixWheel:
            positions = [
                .motorhomeFrontLeft, .motorhomeFrontRight,
                .motorhomeRearLeftOuter, .motorhomeRearLeftInner,
                .motorhomeRearRightInner, .motorhomeRearRightOuter
            ]
        }
        if includeSpare {
            return positions + [layout.sparePosition]
        }
        return positions
    }

    static func inspectionRequiresProfessionalReview(_ inspection: TyreInspection) -> Bool {
        inspection.hasSeriousDefect || inspection.overallCondition == .monitor || inspection.overallCondition == .replace
    }

    static func rollLatestInspection(_ inspection: TyreInspection, into record: TyreRecord) {
        record.latestInspectionDate = inspection.inspectionDate
        if let pressurePSI = inspection.pressurePSI {
            record.latestPressurePSI = pressurePSI
            record.latestPressureDate = inspection.inspectionDate
        }
        if let treadDepthMM = inspection.treadDepthMM {
            record.latestTreadDepthMM = treadDepthMM
        }
        if inspection.overallCondition != .notChecked {
            record.condition = inspection.overallCondition
        }
        record.updatedAt = Date()
    }
}

private extension TyreLayout {
    var sparePosition: TyrePosition {
        switch self {
        case .caravanSingleAxle, .caravanTwinAxle:
            return .caravanSpare
        case .motorhomeFourWheel, .motorhomeSixWheel:
            return .motorhomeSpare
        }
    }
}
