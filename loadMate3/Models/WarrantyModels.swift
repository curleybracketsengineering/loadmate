import Foundation
import SwiftData

enum WarrantyPurchaseCondition: String, Codable, CaseIterable, Identifiable {
    case newPurchase
    case usedPurchase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newPurchase: return "New"
        case .usedPurchase: return "Used"
        }
    }
}

enum WarrantyOwnershipType: String, Codable, CaseIterable, Identifiable {
    case original
    case subsequent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original owner"
        case .subsequent: return "Subsequent owner"
        }
    }
}

enum WarrantyServiceType: String, Codable, CaseIterable, Identifiable {
    case normalService
    case serviceWithBodyCheck
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normalService: return "Normal service"
        case .serviceWithBodyCheck: return "Service with body check"
        case .custom: return "Custom"
        }
    }

    var defaultRequirementDescription: String {
        switch self {
        case .normalService:
            return "Annual habitation service as required by your warranty terms."
        case .serviceWithBodyCheck:
            return "Annual service including body check as required by your warranty terms."
        case .custom:
            return ""
        }
    }
}

enum WarrantyEventStatus: String, Codable {
    case completed
    case overdue
    case inWindow
    case upcoming
}

@Model
final class WarrantyPlan {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var isUnderWarranty: Bool = true
    var warrantyExpiryDate: Date?
    var manufacturer: String = ""
    var modelYear: Int?
    var purchaseDate: Date = Date()
    var purchaseConditionRaw: String = WarrantyPurchaseCondition.newPurchase.rawValue
    var ownershipTypeRaw: String = WarrantyOwnershipType.original.rawValue
    var warrantyType: String = ""
    var durationYears: Int = 8
    var handbookNotes: String = ""
    var templateID: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WarrantyEvent.plan)
    var events: [WarrantyEvent]?

    init(id: UUID = UUID(), vehicleID: UUID) {
        self.id = id
        self.vehicleID = vehicleID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var purchaseCondition: WarrantyPurchaseCondition {
        get { WarrantyPurchaseCondition(rawValue: purchaseConditionRaw) ?? .newPurchase }
        set { purchaseConditionRaw = newValue.rawValue }
    }

    var ownershipType: WarrantyOwnershipType {
        get { WarrantyOwnershipType(rawValue: ownershipTypeRaw) ?? .original }
        set { ownershipTypeRaw = newValue.rawValue }
    }
}

@Model
final class WarrantyEvent {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var yearNumber: Int = 0
    var scheduledDate: Date = Date()
    var daysBefore: Int = 60
    var daysAfter: Int = 30
    var serviceTypeRaw: String = WarrantyServiceType.normalService.rawValue
    var requirementDescription: String = ""
    var sortOrder: Int = 0
    var isManual: Bool = false
    var completedDate: Date?
    var linkedDocumentIDsRaw: String = ""
    var linkedMaintenanceID: UUID?
    var linkedFaultID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var plan: WarrantyPlan?

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceAttachment.warrantyEvent)
    var attachments: [MaintenanceAttachment]?

    init(id: UUID = UUID(), vehicleID: UUID) {
        self.id = id
        self.vehicleID = vehicleID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var serviceType: WarrantyServiceType {
        get { WarrantyServiceType(rawValue: serviceTypeRaw) ?? .normalService }
        set { serviceTypeRaw = newValue.rawValue }
    }

    var linkedDocumentIDs: [UUID] {
        get {
            linkedDocumentIDsRaw
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces)) }
        }
        set {
            linkedDocumentIDsRaw = newValue.map(\.uuidString).joined(separator: ",")
        }
    }
}

extension WarrantyPlan {
    var eventsList: [WarrantyEvent] {
        (events ?? []).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.scheduledDate < rhs.scheduledDate
        }
    }
}

extension WarrantyEvent {
    var attachmentsList: [MaintenanceAttachment] {
        (attachments ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var displayTitle: String {
        if yearNumber > 0 {
            return "Year \(yearNumber)"
        }
        if !requirementDescription.isEmpty {
            return requirementDescription
        }
        return serviceType.displayName
    }

    var requirementText: String {
        let trimmed = requirementDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return serviceType.defaultRequirementDescription
    }
}
