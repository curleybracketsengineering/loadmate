import Foundation
import SwiftData

enum TyreLayout: String, Codable, CaseIterable, Identifiable {
    case caravanSingleAxle
    case caravanTwinAxle
    case motorhomeFourWheel
    case motorhomeSixWheel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .caravanSingleAxle:
            return "Single axle"
        case .caravanTwinAxle:
            return "Twin axle"
        case .motorhomeFourWheel:
            return "Four-wheel configuration"
        case .motorhomeSixWheel:
            return "Six-wheel configuration"
        }
    }
}

enum TyrePosition: String, Codable, CaseIterable, Identifiable {
    case caravanLeft
    case caravanRight
    case caravanFrontLeft
    case caravanFrontRight
    case caravanRearLeft
    case caravanRearRight
    case caravanSpare

    case motorhomeFrontLeft
    case motorhomeFrontRight
    case motorhomeRearLeft
    case motorhomeRearRight
    case motorhomeRearLeftOuter
    case motorhomeRearLeftInner
    case motorhomeRearRightInner
    case motorhomeRearRightOuter
    case motorhomeSpare

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .caravanLeft: return "Left"
        case .caravanRight: return "Right"
        case .caravanFrontLeft: return "Front left"
        case .caravanFrontRight: return "Front right"
        case .caravanRearLeft: return "Rear left"
        case .caravanRearRight: return "Rear right"
        case .caravanSpare: return "Spare"
        case .motorhomeFrontLeft: return "Front left"
        case .motorhomeFrontRight: return "Front right"
        case .motorhomeRearLeft: return "Rear left"
        case .motorhomeRearRight: return "Rear right"
        case .motorhomeRearLeftOuter: return "Rear left outer"
        case .motorhomeRearLeftInner: return "Rear left inner"
        case .motorhomeRearRightInner: return "Rear right inner"
        case .motorhomeRearRightOuter: return "Rear right outer"
        case .motorhomeSpare: return "Spare"
        }
    }

    var isSpare: Bool {
        self == .caravanSpare || self == .motorhomeSpare
    }
}

enum TyrePhotoKind: String, Codable, CaseIterable, Identifiable {
    case sidewall
    case tread
    case fullTyre
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sidewall: return "Sidewall"
        case .tread: return "Tread"
        case .fullTyre: return "Full tyre"
        case .general: return "General"
        }
    }
}

enum TyreCondition: String, Codable, CaseIterable, Identifiable {
    case notChecked
    case good
    case monitor
    case replace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notChecked: return "Not checked"
        case .good: return "Good"
        case .monitor: return "Monitor"
        case .replace: return "Replace"
        }
    }
}

@Model
final class TyreRecord {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var positionRaw: String = TyrePosition.caravanLeft.rawValue
    var isSpare: Bool = false

    var manufacturer: String = ""
    var modelName: String = ""
    var tyreSize: String = ""
    var loadIndex: String = ""
    var speedRating: String = ""

    var dateCode: String = ""
    var manufactureWeek: Int?
    var manufactureYear: Int?
    var manufactureDate: Date?

    var recommendedPressurePSI: Double?
    var latestPressurePSI: Double?
    var latestPressureDate: Date?

    var latestTreadDepthMM: Double?
    var latestInspectionDate: Date?

    var conditionRaw: String = TyreCondition.notChecked.rawValue
    var notes: String = ""

    var installedDate: Date?
    var removedDate: Date?
    var isCurrentlyFitted: Bool = true

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TyreInspection.tyreRecord)
    var inspections: [TyreInspection]?

    @Relationship(deleteRule: .cascade, inverse: \TyrePhoto.tyreRecord)
    var photos: [TyrePhoto]?

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        position: TyrePosition,
        isSpare: Bool? = nil
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.positionRaw = position.rawValue
        self.isSpare = isSpare ?? position.isSpare
        self.conditionRaw = TyreCondition.notChecked.rawValue
        self.isCurrentlyFitted = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var position: TyrePosition {
        get { TyrePosition(rawValue: positionRaw) ?? .caravanLeft }
        set { positionRaw = newValue.rawValue }
    }

    var condition: TyreCondition {
        get { TyreCondition(rawValue: conditionRaw) ?? .notChecked }
        set { conditionRaw = newValue.rawValue }
    }
}

@Model
final class TyreInspection {
    var id: UUID = UUID()
    var tyreRecordID: UUID = UUID()
    var inspectionDate: Date = Date()

    var pressurePSI: Double?
    var treadDepthMM: Double?

    var hasCuts: Bool = false
    var hasBulges: Bool = false
    var hasCracking: Bool = false
    var hasUnevenWear: Bool = false
    var hasEmbeddedObjects: Bool = false
    var valveAppearsSound: Bool?
    var wheelNutsChecked: Bool?

    var overallConditionRaw: String = TyreCondition.notChecked.rawValue
    var notes: String = ""

    var createdAt: Date = Date()

    var tyreRecord: TyreRecord?

    @Relationship(deleteRule: .cascade, inverse: \TyrePhoto.inspection)
    var photos: [TyrePhoto]?

    init(
        id: UUID = UUID(),
        tyreRecord: TyreRecord,
        inspectionDate: Date = Date()
    ) {
        self.id = id
        self.tyreRecordID = tyreRecord.id
        self.tyreRecord = tyreRecord
        self.inspectionDate = inspectionDate
        self.createdAt = Date()
        self.overallConditionRaw = TyreCondition.notChecked.rawValue
    }

    var overallCondition: TyreCondition {
        get { TyreCondition(rawValue: overallConditionRaw) ?? .notChecked }
        set { overallConditionRaw = newValue.rawValue }
    }

    var hasSeriousDefect: Bool {
        hasCuts || hasBulges || hasCracking || hasUnevenWear || hasEmbeddedObjects
    }
}

@Model
final class TyrePhoto {
    var id: UUID = UUID()
    var tyreRecordID: UUID = UUID()
    var kindRaw: String = TyrePhotoKind.general.rawValue
    var capturedAt: Date = Date()
    var localFileName: String = ""
    var caption: String = ""
    var createdAt: Date = Date()

    var tyreRecord: TyreRecord?
    var inspection: TyreInspection?

    init(
        id: UUID = UUID(),
        tyreRecord: TyreRecord,
        inspection: TyreInspection? = nil,
        kind: TyrePhotoKind = .general,
        capturedAt: Date = Date(),
        localFileName: String
    ) {
        self.id = id
        self.tyreRecordID = tyreRecord.id
        self.tyreRecord = tyreRecord
        self.inspection = inspection
        self.kindRaw = kind.rawValue
        self.capturedAt = capturedAt
        self.localFileName = localFileName
        self.createdAt = Date()
    }

    var kind: TyrePhotoKind {
        get { TyrePhotoKind(rawValue: kindRaw) ?? .general }
        set { kindRaw = newValue.rawValue }
    }
}

extension TyreRecord {
    var inspectionsList: [TyreInspection] {
        (inspections ?? []).sorted { $0.inspectionDate > $1.inspectionDate }
    }

    var photosList: [TyrePhoto] {
        (photos ?? []).sorted { $0.capturedAt > $1.capturedAt }
    }

    func generalPhotosList() -> [TyrePhoto] {
        photosList.filter { $0.inspection == nil }
    }
}

extension TyreInspection {
    var photosList: [TyrePhoto] {
        (photos ?? []).sorted { $0.capturedAt > $1.capturedAt }
    }
}

extension TyreRecord {

    var displayName: String {
        position.displayName
    }

    var ageText: String {
        TyreSupport.ageText(for: manufactureDate)
    }

    var ageAssessment: TyreAgeAssessment {
        TyreSupport.ageAssessment(for: self)
    }

    var pressureAssessment: TyrePressureAssessment {
        TyreSupport.pressureAssessment(for: self)
    }

    var statusLevel: TyreStatusLevel {
        if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manufactureDate == nil {
            return .incomplete
        }

        let levels = [ageAssessment.level, pressureAssessment.level, conditionStatusLevel]
        if levels.contains(.action) { return .action }
        if levels.contains(.attention) { return .attention }
        if levels.contains(.incomplete) { return .incomplete }
        return .current
    }

    var conditionStatusLevel: TyreStatusLevel {
        switch condition {
        case .good:
            return .current
        case .monitor:
            return .attention
        case .replace:
            return .action
        case .notChecked:
            return .incomplete
        }
    }

    var alertMessages: [String] {
        var messages: [String] = []
        let age = ageAssessment
        if let message = age.message, age.level != .current {
            messages.append(message)
        }

        let pressure = pressureAssessment
        if pressure.level == .attention || pressure.level == .action || pressure.level == .incomplete {
            messages.append(pressure.message)
        }

        if let inspectionDate = latestInspectionDate,
           Calendar.current.dateComponents([.day], from: inspectionDate, to: Date()).day ?? 0 > 90 {
            messages.append("Inspection is more than 90 days old.")
        }
        return messages
    }
}
