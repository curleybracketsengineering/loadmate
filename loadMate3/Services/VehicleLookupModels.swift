import Foundation

/// Provider-independent vehicle lookup result for Lyneqo.
/// Optional fields are omitted when the upstream source does not return them.
struct VehicleLookupResult: Equatable, Sendable {
    var registration: String
    var displayRegistration: String
    var make: String?
    var model: String?
    var colour: String?
    var fuelType: String?
    var vehicleType: String?
    var yearOfManufacture: Int?
    var monthOfFirstRegistration: String?
    var engineCapacityCc: Int?
    var co2EmissionsGPerKm: Double?
    var latestOdometerMiles: Int?
    var taxStatus: String?
    var taxDueDate: Date?
    var motStatus: String?
    var motExpiryDate: Date?
    var motDaysRemaining: Int?
    var lastMotResult: String?
    var lastMotDate: Date?
    var firstMotDue: Date?
    var totalMotTests: Int?
    var motPassRate: Double?
    var imminentMot: Bool?
    var markedForExport: Bool?
    var ulezCompliant: Bool?
    var checkedAt: Date

    /// Year of first registration from `YYYY-MM`, falling back to year of manufacture.
    var firstRegistrationYear: Int? {
        if let month = monthOfFirstRegistration?.trimmingCharacters(in: .whitespacesAndNewlines),
           month.count >= 4,
           let year = Int(month.prefix(4)),
           (1900...2100).contains(year) {
            return year
        }
        return yearOfManufacture
    }
}

enum VehicleLookupDisplay {
    static let motDueCaption = "MOT due"

    static func identityLine(manufacturer: String, modelName: String) -> String? {
        let parts = [manufacturer, modelName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func identityLine(for profile: VehicleProfile) -> String? {
        identityLine(manufacturer: profile.manufacturer, modelName: profile.modelName)
    }

    /// Last MOT date, or `MOT due` when the certificate has expired.
    /// If expiry is unknown, last MOT is treated as valid for one year.
    static func lastMOTCaption(
        lastMotDate: Date?,
        motExpiryDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard lastMotDate != nil || motExpiryDate != nil else { return nil }

        let today = calendar.startOfDay(for: now)
        let expiry: Date? = {
            if let motExpiryDate {
                return calendar.startOfDay(for: motExpiryDate)
            }
            if let lastMotDate {
                return calendar.date(byAdding: .year, value: 1, to: calendar.startOfDay(for: lastMotDate))
            }
            return nil
        }()

        if let expiry, expiry < today {
            return motDueCaption
        }
        if let lastMotDate {
            return Formatters.date(lastMotDate)
        }
        return motDueCaption
    }

    static func lastMOTCaption(for profile: VehicleProfile, now: Date = Date(), calendar: Calendar = .current) -> String? {
        lastMOTCaption(
            lastMotDate: profile.lastMotDate,
            motExpiryDate: profile.motExpiryDate,
            now: now,
            calendar: calendar
        )
    }

    static func hasSummary(for profile: VehicleProfile) -> Bool {
        identityLine(for: profile) != nil
            || profile.firstRegistrationYear != nil
            || lastMOTCaption(for: profile) != nil
    }
}

enum VehicleLookupError: Error, Equatable, LocalizedError, Sendable {
    case invalidRegistration
    case notFound
    case noNetwork
    case serviceUnavailable
    case rateLimited
    case quotaExhausted
    case configuration
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidRegistration:
            return "That does not look like a valid UK registration. Check the letters and numbers and try again."
        case .notFound:
            return "No vehicle was found for that registration."
        case .noNetwork:
            return "No network connection. Check you are online and try again."
        case .serviceUnavailable:
            return "Vehicle lookup is temporarily unavailable. Try again shortly."
        case .rateLimited:
            return "Too many lookup requests. Please wait and try again later."
        case .quotaExhausted:
            return "Lyneqo is a free application. Unfortunately, we've run out of credits this month. Credits reset on the 13th of each month. Lyneqo uses ZyFy.uk — visit that site as an individual user to look up the same vehicle data."
        case .configuration:
            return "Vehicle lookup is not configured on this device."
        case .unexpectedResponse:
            return "Vehicle lookup returned an unexpected result. Try again shortly."
        }
    }
}

enum UKRegistration {
    static func normalizeForLookup(_ raw: String) -> String {
        raw.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    static func displayFormatted(_ raw: String) -> String {
        let normalized = normalizeForLookup(raw)
        guard !normalized.isEmpty else { return "" }

        if normalized.count == 7, normalized.wholeMatch(of: /^[A-Z]{2}[0-9]{2}[A-Z]{3}$/) != nil {
            return "\(normalized.prefix(4)) \(normalized.suffix(3))"
        }
        if normalized.count == 7, normalized.wholeMatch(of: /^[A-Z]{3}[0-9]{4}$/) != nil {
            return "\(normalized.prefix(3)) \(normalized.suffix(4))"
        }
        if let match = normalized.wholeMatch(of: /^([A-Z])([0-9]{1,3})([A-Z]{3})$/) {
            return "\(match.1)\(match.2) \(match.3)"
        }
        if let match = normalized.wholeMatch(of: /^([A-Z]{1,3})([0-9]{1,3})([A-Z])$/) {
            return "\(match.1) \(match.2)\(match.3)"
        }
        return normalized
    }

    static func isPlausible(_ raw: String) -> Bool {
        let normalized = normalizeForLookup(raw)
        guard (2...8).contains(normalized.count) else { return false }
        guard normalized.contains(where: \.isLetter) else { return false }
        return normalized.allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// Stricter than `isPlausible` — used when reading a plate from a photo.
    static func isLikelyCompletePlate(_ raw: String) -> Bool {
        let normalized = normalizeForLookup(raw)
        guard (5...8).contains(normalized.count) else { return false }
        guard normalized.contains(where: \.isLetter), normalized.contains(where: \.isNumber) else { return false }

        if normalized.wholeMatch(of: /^[A-Z]{2}[0-9]{2}[A-Z]{3}$/) != nil { return true }
        if normalized.wholeMatch(of: /^[A-Z][0-9]{1,3}[A-Z]{3}$/) != nil { return true }
        if normalized.wholeMatch(of: /^[A-Z]{3}[0-9]{1,3}[A-Z]$/) != nil { return true }
        if normalized.wholeMatch(of: /^[A-Z]{3}[0-9]{4}$/) != nil { return true }
        if normalized.wholeMatch(of: /^[A-Z]{1,3}[0-9]{2,4}$/) != nil { return true }
        if normalized.wholeMatch(of: /^[0-9]{1,4}[A-Z]{1,3}$/) != nil { return true }
        return false
    }
}
