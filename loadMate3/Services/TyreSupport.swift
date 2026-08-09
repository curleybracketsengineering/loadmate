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

/// Shared specification fields that can safely be copied between tyre positions.
/// Excludes readings, condition, notes, photos and position identity.
struct TyreCopyableDetails: Equatable {
    var manufacturer: String = ""
    var modelName: String = ""
    var tyreSize: String = ""
    var loadIndex: String = ""
    var speedRating: String = ""
    var dateCode: String = ""
    var recommendedPressurePSI: Double?

    var hasAnyValue: Bool {
        !trimmed(manufacturer).isEmpty
            || !trimmed(modelName).isEmpty
            || !trimmed(tyreSize).isEmpty
            || !trimmed(loadIndex).isEmpty
            || !trimmed(speedRating).isEmpty
            || !trimmed(dateCode).isEmpty
            || recommendedPressurePSI != nil
    }

    var summaryLine: String {
        let brandModel = [trimmed(manufacturer), trimmed(modelName)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let size = trimmed(tyreSize)
        switch (brandModel.isEmpty, size.isEmpty) {
        case (false, false):
            return "\(brandModel) • \(size)"
        case (false, true):
            return brandModel
        case (true, false):
            return size
        case (true, true):
            let code = trimmed(dateCode)
            return code.isEmpty ? "No shared details recorded" : "Date code \(code)"
        }
    }

    static func from(_ record: TyreRecord) -> TyreCopyableDetails {
        TyreCopyableDetails(
            manufacturer: record.manufacturer,
            modelName: record.modelName,
            tyreSize: record.tyreSize,
            loadIndex: record.loadIndex,
            speedRating: record.speedRating,
            dateCode: record.dateCode,
            recommendedPressurePSI: record.recommendedPressurePSI
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TyreSupport {
    static let tyreDisclaimer = "Lyneqo Caravan & Motorhome helps you record tyre information and identify items that may need attention. It cannot inspect a tyre or confirm that a tyre is safe for use. Always follow the vehicle, caravan and tyre manufacturer’s instructions. If a tyre is damaged, incorrectly inflated, unusually worn or of uncertain condition, have it inspected by a qualified tyre professional before travelling."

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
        guard let compact = compactAgeText(for: manufactureDate, now: now) else {
            return "Age unknown"
        }
        return "\(compact) old"
    }

    /// Age without the trailing "old", for compact tyre cards.
    static func compactAgeText(for manufactureDate: Date?, now: Date = Date()) -> String? {
        guard let manufactureDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: manufactureDate, to: now)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)

        if years < 1 {
            return months == 1 ? "1 month" : "\(months) months"
        }

        let yearText = years == 1 ? "1 year" : "\(years) years"
        if months == 0 {
            return yearText
        }
        let monthText = months == 1 ? "1 month" : "\(months) months"
        return "\(yearText) \(monthText)"
    }

    static func dateCodeCaption(for record: TyreRecord) -> String {
        if let week = record.manufactureWeek, let year = record.manufactureYear {
            return "Week \(week) • \(year)"
        }
        let trimmed = record.dateCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 4, let week = Int(trimmed.prefix(2)), let shortYear = Int(trimmed.suffix(2)) {
            let fullYear = shortYear >= 80 ? 1900 + shortYear : 2000 + shortYear
            return "Week \(week) • \(fullYear)"
        }
        return "Date not recorded"
    }

    /// Basic identity line for history (brand, model, size) — not pressure readings.
    static func historyIdentitySummary(for record: TyreRecord) -> String {
        let copyable = TyreCopyableDetails.from(record)
        var parts: [String] = []
        let brandModelSize = copyable.summaryLine
        if brandModelSize != "No shared details recorded" {
            parts.append(brandModelSize)
        }
        let loadSpeed = [record.loadIndex, record.speedRating]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        if !loadSpeed.isEmpty {
            parts.append("LI/SR \(loadSpeed)")
        }
        if parts.isEmpty {
            return "Details not recorded"
        }
        return parts.joined(separator: " • ")
    }

    static func historyServicePeriod(for record: TyreRecord) -> String {
        let fitted = record.installedDate.map { "Fitted \(Formatters.date($0))" }
        let removed = record.removedDate.map { "Removed \(Formatters.date($0))" }
        switch (fitted, removed) {
        case let (fit?, rem?):
            return "\(fit) · \(rem)"
        case let (fit?, nil):
            return fit
        case let (nil, rem?):
            return rem
        case (nil, nil):
            return "Service dates not recorded"
        }
    }

    static func conditionCallToAction(for record: TyreRecord) -> String {
        switch record.statusLevel {
        case .action:
            if record.condition == .replace {
                return "Plan replacement"
            }
            if record.ageAssessment.level == .action {
                return "Inspect / plan replacement"
            }
            if record.pressureAssessment.level == .action {
                return "Check pressure"
            }
            return "Needs attention"
        case .attention:
            if record.ageAssessment.level == .attention {
                return record.ageAssessment.status
            }
            if record.pressureAssessment.level == .attention {
                return "Check pressure"
            }
            if record.condition == .monitor {
                return "Monitor"
            }
            return "Needs review"
        case .incomplete:
            if record.manufactureDate == nil {
                return "Tyre information required"
            }
            if record.recommendedPressurePSI == nil {
                return "Record target pressure"
            }
            if record.condition == .notChecked {
                return "Record condition"
            }
            return "Complete details"
        case .current:
            return record.condition == .good ? "Good" : "Current"
        }
    }

    static func layoutSummary(for profile: VehicleProfile, records: [TyreRecord]) -> String {
        let roadCount = records.filter { !$0.isSpare }.count
        let hasSpare = records.contains(where: \.isSpare)
        let tyrePart: String
        if hasSpare {
            tyrePart = "\(roadCount) road \(roadCount == 1 ? "tyre" : "tyres") + spare"
        } else {
            tyrePart = "\(roadCount) \(roadCount == 1 ? "tyre" : "tyres")"
        }
        return "\(profile.kind.displayName) • \(tyrePart)"
    }

    static func actionNeededCount(in records: [TyreRecord]) -> Int {
        records.filter { $0.statusLevel == .action || $0.statusLevel == .attention || $0.statusLevel == .incomplete }.count
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

    static func draftRequiresProfessionalReview(
        hasCuts: Bool,
        hasBulges: Bool,
        hasCracking: Bool,
        hasUnevenWear: Bool,
        hasEmbeddedObjects: Bool,
        valveAppearsSound: Bool,
        wheelNutsChecked: Bool,
        overallCondition: TyreCondition
    ) -> Bool {
        let hasSeriousDefect = hasCuts || hasBulges || hasCracking || hasUnevenWear || hasEmbeddedObjects
        let checkFailed = !valveAppearsSound || !wheelNutsChecked
        return hasSeriousDefect || checkFailed || overallCondition == .monitor || overallCondition == .replace
    }

    static func draftHasSeriousDefect(
        hasCuts: Bool,
        hasBulges: Bool,
        hasCracking: Bool,
        hasUnevenWear: Bool,
        hasEmbeddedObjects: Bool
    ) -> Bool {
        hasCuts || hasBulges || hasCracking || hasUnevenWear || hasEmbeddedObjects
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
