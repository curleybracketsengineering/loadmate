import Foundation
import SwiftData

enum TripExpenseCategory: String, CaseIterable, Identifiable, Sendable {
    case fuel
    case site
    case tollsRoad
    case ferry
    case parking
    case food
    case activities
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fuel: return "Fuel"
        case .site: return "Site"
        case .tollsRoad: return "Tolls/Road"
        case .ferry: return "Ferry"
        case .parking: return "Parking"
        case .food: return "Food"
        case .activities: return "Activities"
        case .other: return "Other"
        }
    }

    static func resolved(from raw: String) -> TripExpenseCategory? {
        TripExpenseCategory(rawValue: raw)
    }
}

enum TripRecordPhase: String, CaseIterable, Identifiable, Sendable {
    case current
    case upcoming
    case completed

    var id: String { rawValue }

    var listTitle: String {
        switch self {
        case .current: return "Current"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        }
    }
}

/// Journey history for a vehicle. Soft-references the profile and loading configuration by UUID.
/// User-facing name is "Trip"; the SwiftData loading-setup type remains `Trip`.
@Model
final class TripRecord {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var vehicleProfileID: UUID = UUID()
    var loadingConfigurationID: UUID?
    var currencyCode: String = "GBP"

    @Relationship(deleteRule: .cascade, inverse: \TripStop.record)
    var stops: [TripStop]?

    @Relationship(deleteRule: .cascade, inverse: \TripLeg.record)
    var legs: [TripLeg]?

    @Relationship(deleteRule: .cascade, inverse: \TripExpense.record)
    var expenses: [TripExpense]?

    init(
        id: UUID = UUID(),
        vehicleProfileID: UUID,
        name: String = "",
        startDate: Date = Date(),
        currencyCode: String = "GBP"
    ) {
        self.id = id
        self.vehicleProfileID = vehicleProfileID
        self.name = name
        self.startDate = startDate
        self.currencyCode = currencyCode
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    var stopsList: [TripStop] {
        (stops ?? []).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var legsList: [TripLeg] {
        (legs ?? []).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var expensesList: [TripExpense] {
        (expenses ?? []).sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

@Model
final class TripStop {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var locationName: String = ""
    var arrivedAt: Date?
    var departedAt: Date?
    var siteCostMinorUnits: Int64?
    var notes: String = ""
    var record: TripRecord?

    init(id: UUID = UUID(), record: TripRecord? = nil) {
        self.id = id
        self.record = record
    }
}

@Model
final class TripLeg {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var fromName: String = ""
    var toName: String = ""
    var mileage: Double?
    var travelMinutes: Int?
    var travelledOn: Date?
    var notes: String = ""
    var record: TripRecord?

    init(id: UUID = UUID(), record: TripRecord? = nil) {
        self.id = id
        self.record = record
    }
}

@Model
final class TripExpense {
    var id: UUID = UUID()
    var date: Date = Date()
    var categoryRaw: String = TripExpenseCategory.fuel.rawValue
    var amountMinorUnits: Int64 = 0
    var notes: String = ""
    var record: TripRecord?

    init(id: UUID = UUID(), record: TripRecord? = nil) {
        self.id = id
        self.record = record
    }

    var category: TripExpenseCategory {
        get { TripExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
