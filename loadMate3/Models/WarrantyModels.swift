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

/// UK / NI motorhome roadworthiness test class used to drive MOT schedule generation.
enum UKMotorhomeMOTClass: String, Codable, CaseIterable, Identifiable {
    case class4
    case class7
    case hgvAnnual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .class4: return "Class 4 MOT"
        case .class7: return "Class 7 MOT"
        case .hgvAnnual: return "HGV annual test"
        }
    }

    var shortLabel: String {
        switch self {
        case .class4: return "Class 4"
        case .class7: return "Class 7"
        case .hgvAnnual: return "HGV annual"
        }
    }

    var summary: String {
        switch self {
        case .class4:
            return "Most standard motorhomes under 3,500 kg (typical motor caravan Class 4 test)."
        case .class7:
            return "Heavier light commercial configuration, usually 3,000–3,500 kg. Some motorhomes in this weight band still use Class 4 depending on body type — confirm with your V5C / test station."
        case .hgvAnnual:
            return "Goods / heavy vehicles over 3,500 kg design gross weight — annual test from the first year (not Class 4/7 MOT)."
        }
    }

    /// First statutory test year after first registration / purchase anniversary used by Lyneqo Caravan & Motorhome.
    var firstTestYear: Int {
        switch self {
        case .class4, .class7: return 3
        case .hgvAnnual: return 1
        }
    }

    var daysBefore: Int { 30 }
    var daysAfter: Int { 0 }

    var requirementDescription: String {
        switch self {
        case .class4:
            return "UK Class 4 MOT for most standard motorhomes under 3,500 kg. First due from the third anniversary of first registration, then annually. Book before the due date. Confirm class with your V5C and test station."
        case .class7:
            return "UK Class 7 MOT for heavier light vehicles typically 3,000–3,500 kg. First due from the third anniversary of first registration, then annually. Some motorhomes in this weight band remain Class 4 — confirm with your V5C and test station."
        case .hgvAnnual:
            return "UK HGV / goods vehicle annual test for vehicles over 3,500 kg DGW. First due from the first anniversary of first registration, then annually. Book at an authorised goods vehicle testing station and confirm plating/test class for your vehicle."
        }
    }

    var eventTitlePrefix: String {
        switch self {
        case .class4: return "Class 4 MOT"
        case .class7: return "Class 7 MOT"
        case .hgvAnnual: return "HGV annual test"
        }
    }

    /// Suggest a starter class from plated MAM / DGW (kg). Owner can override.
    static func suggested(forPlatedMassKg massKg: Double) -> UKMotorhomeMOTClass {
        guard massKg > 0 else { return .class4 }
        if massKg > 3_500 { return .hgvAnnual }
        if massKg >= 3_000 { return .class7 }
        return .class4
    }
}

enum WarrantyServiceType: String, Codable, CaseIterable, Identifiable {
    case normalService
    case serviceWithBodyCheck
    case mot
    case vehicleInspection
    case insuranceRenewal
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normalService: return "Normal service"
        case .serviceWithBodyCheck: return "Service with body check"
        case .mot: return "MOT"
        case .vehicleInspection: return "Vehicle inspection"
        case .insuranceRenewal: return "Insurance check"
        case .custom: return "Custom"
        }
    }

    var defaultRequirementDescription: String {
        switch self {
        case .normalService:
            return "Annual habitation service as required by your warranty terms."
        case .serviceWithBodyCheck:
            return "Annual service including body check as required by your warranty terms."
        case .mot:
            return UKMotorhomeMOTClass.class4.requirementDescription
        case .vehicleInspection:
            return "Local roadworthiness / vehicle inspection reminder. Rules vary by country and region — confirm the first due date, interval, and test class with your local authority, and edit this schedule to match."
        case .insuranceRenewal:
            return WarrantySupport.insuranceRenewalRequirement(for: .caravan)
        case .custom:
            return ""
        }
    }

    var isStatutoryInspection: Bool {
        self == .mot || self == .vehicleInspection
    }
}

enum WarrantyEventStatus: String, Codable {
    case completed
    case overdue
    case inWindow
    case upcoming
    case planned
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
    /// UK motorhome MOT / annual test class (`UKMotorhomeMOTClass` raw value). Nil outside UK or when unset.
    var motClassRaw: String?
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

    var motClass: UKMotorhomeMOTClass? {
        get {
            guard let motClassRaw else { return nil }
            return UKMotorhomeMOTClass(rawValue: motClassRaw)
        }
        set { motClassRaw = newValue?.rawValue }
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
            let lhsDay = Calendar.current.startOfDay(for: lhs.scheduledDate)
            let rhsDay = Calendar.current.startOfDay(for: rhs.scheduledDate)
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.yearNumber < rhs.yearNumber
        }
    }
}

extension WarrantyEvent {
    var attachmentsList: [MaintenanceAttachment] {
        (attachments ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// Manufacturer milestone year (e.g. Swift 3/6/10) with no after-grace — must finish on/before anniversary.
    var isImportantMilestone: Bool {
        serviceType == .serviceWithBodyCheck
    }

    var displayTitle: String {
        if serviceType == .mot {
            if yearNumber > 0 {
                return "Year \(yearNumber) \(motTitleSuffix)"
            }
            return motTitleSuffix
        }
        if serviceType == .vehicleInspection {
            return yearNumber > 0 ? "Year \(yearNumber) vehicle inspection" : "Vehicle inspection"
        }
        if serviceType == .insuranceRenewal {
            return "Insurance"
        }
        if yearNumber > 0 {
            return isImportantMilestone ? "Year \(yearNumber) · Milestone" : "Year \(yearNumber)"
        }
        if !requirementDescription.isEmpty {
            return requirementDescription
        }
        return serviceType.displayName
    }

    private var motTitleSuffix: String {
        let text = requirementDescription.lowercased()
        if text.contains("class 7") { return "Class 7 MOT" }
        if text.contains("hgv") || text.contains("goods vehicle annual") { return "HGV annual test" }
        if text.contains("class 4") { return "Class 4 MOT" }
        return "MOT"
    }

    var requirementText: String {
        let trimmed = requirementDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return serviceType.defaultRequirementDescription
    }
}
