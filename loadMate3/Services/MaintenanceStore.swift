import Foundation
import SwiftData

enum MaintenanceStore {
    @discardableResult
    static func createRecord(for vehicleID: UUID, in context: ModelContext) -> MaintenanceRecord {
        let record = MaintenanceRecord(vehicleID: vehicleID)
        context.insert(record)
        try? context.save()
        return record
    }

    static func save(
        record: MaintenanceRecord,
        title: String,
        category: MaintenanceCategory,
        serviceDate: Date,
        cost: Double?,
        supplier: String,
        notes: String,
        reminderDate: Date?,
        vehicleMileage: Double?,
        in context: ModelContext
    ) {
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.category = category
        record.serviceDate = serviceDate
        record.cost = cost
        record.supplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.reminderDate = reminderDate
        record.vehicleMileage = vehicleMileage
        record.updatedAt = Date()
        try? context.save()
    }
}
