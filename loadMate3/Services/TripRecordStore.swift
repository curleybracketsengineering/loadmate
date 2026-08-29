import Foundation
import SwiftData

enum TripRecordStore {
    enum SaveError: LocalizedError {
        case validation([TripRecordValidationIssue])

        var errorDescription: String? {
            switch self {
            case .validation(let issues):
                return issues.map(\.message).joined(separator: "\n")
            }
        }
    }

    static func records(for vehicleID: UUID, from all: [TripRecord]) -> [TripRecord] {
        all.filter { $0.vehicleProfileID == vehicleID }
    }

    static func record(id: UUID, from all: [TripRecord]) -> TripRecord? {
        all.first { $0.id == id }
    }

    static func loadingConfiguration(
        id: UUID?,
        from trips: [Trip]
    ) -> Trip? {
        guard let id else { return nil }
        return trips.first { $0.id == id }
    }

    @discardableResult
    static func save(_ draft: TripRecordDraft, in context: ModelContext) throws -> TripRecord {
        let issues = TripRecordDraft.validate(draft)
        guard issues.isEmpty else { throw SaveError.validation(issues) }

        let prepared = TripRecordDraft.preparedForSave(draft)
        let record: TripRecord
        if let existingID = prepared.existingID,
           let existing = fetchRecord(id: existingID, in: context) {
            record = existing
        } else {
            record = TripRecord(
                vehicleProfileID: prepared.vehicleProfileID,
                currencyCode: prepared.currencyCode
            )
            context.insert(record)
        }

        apply(prepared, to: record, in: context)
        try context.save()
        return record
    }

    static func delete(_ record: TripRecord, in context: ModelContext) {
        context.delete(record)
        try? context.save()
    }

    static func fetchRecord(id: UUID, in context: ModelContext) -> TripRecord? {
        let all = (try? context.fetch(FetchDescriptor<TripRecord>())) ?? []
        return all.first { $0.id == id }
    }

    private static func apply(_ draft: TripRecordDraft, to record: TripRecord, in context: ModelContext) {
        record.name = draft.name
        record.startDate = draft.startDate
        record.endDate = draft.endDate
        record.notes = draft.notes
        record.vehicleProfileID = draft.vehicleProfileID
        record.loadingConfigurationID = draft.loadingConfigurationID
        record.currencyCode = draft.currencyCode
        record.updatedAt = Date()

        syncStops(draft.stops, onto: record, in: context)
        syncLegs(draft.legs, onto: record, in: context)
        syncExpenses(draft.expenses, onto: record, in: context)
    }

    private static func syncStops(_ drafts: [TripStopDraft], onto record: TripRecord, in context: ModelContext) {
        let existing = record.stopsList
        let keepIDs = Set(drafts.map(\.id))
        for stop in existing where !keepIDs.contains(stop.id) {
            context.delete(stop)
        }

        for (index, draft) in drafts.enumerated() {
            let stop = existing.first(where: { $0.id == draft.id }) ?? {
                let created = TripStop(id: draft.id, record: record)
                context.insert(created)
                return created
            }()
            stop.sortOrder = index
            stop.locationName = draft.locationName
            stop.arrivedAt = draft.arrivedAt
            stop.departedAt = draft.departedAt
            stop.siteCostMinorUnits = draft.siteCost.map {
                TripRecordMoney.minorUnits(from: $0, currencyCode: record.currencyCode)
            }
            stop.notes = draft.notes
            stop.record = record
        }
    }

    private static func syncLegs(_ drafts: [TripLegDraft], onto record: TripRecord, in context: ModelContext) {
        let existing = record.legsList
        let keepIDs = Set(drafts.map(\.id))
        for leg in existing where !keepIDs.contains(leg.id) {
            context.delete(leg)
        }

        for (index, draft) in drafts.enumerated() {
            let leg = existing.first(where: { $0.id == draft.id }) ?? {
                let created = TripLeg(id: draft.id, record: record)
                context.insert(created)
                return created
            }()
            leg.sortOrder = index
            leg.fromName = draft.fromName
            leg.toName = draft.toName
            leg.mileage = draft.mileage
            leg.travelMinutes = draft.travelMinutes
            leg.travelledOn = draft.travelledOn
            leg.notes = draft.notes
            leg.record = record
        }
    }

    private static func syncExpenses(_ drafts: [TripExpenseDraft], onto record: TripRecord, in context: ModelContext) {
        let existing = record.expensesList
        let keepIDs = Set(drafts.map(\.id))
        for expense in existing where !keepIDs.contains(expense.id) {
            context.delete(expense)
        }

        for draft in drafts {
            let expense = existing.first(where: { $0.id == draft.id }) ?? {
                let created = TripExpense(id: draft.id, record: record)
                context.insert(created)
                return created
            }()
            expense.date = draft.date
            expense.category = draft.category
            expense.amountMinorUnits = TripRecordMoney.minorUnits(
                from: draft.amount,
                currencyCode: record.currencyCode
            )
            expense.notes = draft.notes
            expense.record = record
        }
    }
}
