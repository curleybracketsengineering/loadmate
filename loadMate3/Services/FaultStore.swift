import Foundation
import SwiftData

enum FaultStore {
    @discardableResult
    static func createRecord(for vehicleID: UUID, in context: ModelContext) -> FaultRecord {
        let record = FaultRecord(vehicleID: vehicleID)
        context.insert(record)
        try? context.save()
        return record
    }

    static func save(
        fault: FaultRecord,
        title: String,
        details: String,
        severity: FaultSeverity,
        status: FaultStatus,
        discoveredDate: Date,
        resolvedDate: Date?,
        repairCost: Double?,
        linkedMaintenanceRecord: MaintenanceRecord?,
        isWarrantyRelated: Bool = false,
        in context: ModelContext
    ) {
        fault.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        fault.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        fault.severity = severity
        fault.status = status
        fault.discoveredDate = discoveredDate
        fault.resolvedDate = status.isResolved ? resolvedDate : nil
        fault.actualRepairCost = repairCost
        fault.estimatedRepairCost = nil
        fault.linkedMaintenanceRecord = linkedMaintenanceRecord
        fault.isWarrantyRelated = isWarrantyRelated
        fault.updatedAt = Date()
        try? context.save()
    }
}
