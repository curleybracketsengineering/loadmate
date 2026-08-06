import Foundation
import SwiftData

enum TyreStore {
    static func activeRecords(for profile: VehicleProfile?, from allRecords: [TyreRecord]) -> [TyreRecord] {
        guard let profile else { return [] }
        return allRecords
            .filter { $0.vehicleID == profile.id && $0.isCurrentlyFitted }
            .sorted { lhs, rhs in
                TyrePosition.allCases.firstIndex(of: lhs.position) ?? 0 < TyrePosition.allCases.firstIndex(of: rhs.position) ?? 0
            }
    }

    static func activeRecords(for profile: VehicleProfile?, in context: ModelContext) -> [TyreRecord] {
        guard let profile else { return [] }
        let descriptor = FetchDescriptor<TyreRecord>()
        let all = (try? context.fetch(descriptor)) ?? []
        return activeRecords(for: profile, from: all)
    }

    static func createLayout(
        for profile: VehicleProfile,
        layout: TyreLayout,
        includeSpare: Bool,
        in context: ModelContext
    ) {
        let existing = activeRecords(for: profile, in: context)
        let targetPositions = Set(TyreSupport.positions(for: layout, includeSpare: includeSpare))

        for record in existing where !targetPositions.contains(record.position) {
            record.isCurrentlyFitted = false
            record.removedDate = Date()
            record.updatedAt = Date()
        }

        let existingPositions = Set(existing.map(\.position))
        for position in targetPositions where !existingPositions.contains(position) {
            context.insert(TyreRecord(vehicleID: profile.id, position: position))
        }

        try? context.save()
    }

    static func replaceTyre(
        _ record: TyreRecord,
        copyManufacturerAndModel: Bool,
        in context: ModelContext
    ) -> TyreRecord {
        record.isCurrentlyFitted = false
        record.removedDate = Date()
        record.updatedAt = Date()

        let replacement = TyreRecord(vehicleID: record.vehicleID, position: record.position, isSpare: record.isSpare)
        replacement.recommendedPressurePSI = record.recommendedPressurePSI
        replacement.tyreSize = record.tyreSize
        replacement.loadIndex = record.loadIndex
        replacement.speedRating = record.speedRating
        if copyManufacturerAndModel {
            replacement.manufacturer = record.manufacturer
            replacement.modelName = record.modelName
        }
        context.insert(replacement)
        try? context.save()
        return replacement
    }

    static func addInspection(
        to record: TyreRecord,
        inspectionDate: Date,
        pressurePSI: Double?,
        treadDepthMM: Double?,
        hasCuts: Bool,
        hasBulges: Bool,
        hasCracking: Bool,
        hasUnevenWear: Bool,
        hasEmbeddedObjects: Bool,
        valveAppearsSound: Bool?,
        wheelNutsChecked: Bool?,
        overallCondition: TyreCondition,
        notes: String,
        in context: ModelContext
    ) -> TyreInspection {
        let inspection = TyreInspection(tyreRecord: record, inspectionDate: inspectionDate)
        inspection.pressurePSI = pressurePSI
        inspection.treadDepthMM = treadDepthMM
        inspection.hasCuts = hasCuts
        inspection.hasBulges = hasBulges
        inspection.hasCracking = hasCracking
        inspection.hasUnevenWear = hasUnevenWear
        inspection.hasEmbeddedObjects = hasEmbeddedObjects
        inspection.valveAppearsSound = valveAppearsSound
        inspection.wheelNutsChecked = wheelNutsChecked
        inspection.overallCondition = overallCondition
        inspection.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        TyreSupport.rollLatestInspection(inspection, into: record)
        context.insert(inspection)
        try? context.save()
        return inspection
    }

    static func suggestedLayout(for records: [TyreRecord], kind: VehicleKind) -> TyreLayout? {
        let positions = Set(records.filter(\.isCurrentlyFitted).map(\.position))
        switch kind {
        case .caravan:
            if positions.contains(.caravanFrontLeft) || positions.contains(.caravanRearLeft) {
                return .caravanTwinAxle
            }
            if positions.contains(.caravanLeft) || positions.contains(.caravanRight) {
                return .caravanSingleAxle
            }
        case .motorhome:
            if positions.contains(.motorhomeRearLeftInner) || positions.contains(.motorhomeRearRightInner) {
                return .motorhomeSixWheel
            }
            if positions.contains(.motorhomeFrontLeft) || positions.contains(.motorhomeRearLeft) {
                return .motorhomeFourWheel
            }
        }
        return nil
    }
}
