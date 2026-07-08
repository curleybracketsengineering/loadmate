import Foundation
import SwiftData

enum DocumentStore {
    @discardableResult
    static func createRecord(for vehicleID: UUID, in context: ModelContext) -> DocumentRecord {
        let record = DocumentRecord(vehicleID: vehicleID)
        context.insert(record)
        try? context.save()
        return record
    }

    static func save(
        record: DocumentRecord,
        title: String,
        category: DocumentCategory,
        dateAdded: Date,
        expiryDate: Date?,
        reminderDate: Date?,
        notes: String,
        in context: ModelContext
    ) {
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.category = category
        record.dateAdded = dateAdded
        record.expiryDate = expiryDate
        record.reminderDate = reminderDate
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.updatedAt = Date()
        try? context.save()
    }
}
