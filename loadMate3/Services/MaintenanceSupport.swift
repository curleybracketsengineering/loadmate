import Foundation

enum MaintenanceHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case maintenance
    case documents
    case faults
    case warranty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .maintenance: return "Maintenance"
        case .documents: return "Documents"
        case .faults: return "Faults"
        case .warranty: return "Warranty"
        }
    }
}

enum MaintenanceReminderKind: String {
    case maintenance
    case documentExpiry
    case documentReminder
    case warrantyEvent
}

struct MaintenanceDashboardSummary {
    let upcomingTitle: String
    let upcomingSubtitle: String
    let outstandingFaults: Int
    let documentCount: Int
    let recentActivityTitle: String
    let recentActivitySubtitle: String
}

struct MaintenanceReminderItem: Identifiable {
    let id: String
    let title: String
    let dueDate: Date
    let subtitle: String
    let kind: MaintenanceReminderKind
}

struct MaintenanceHistoryEntry: Identifiable {
    enum EntryKind {
        case maintenance
        case document
        case faultRaised
        case faultResolved
        case warrantyPurchase
        case warranty
    }

    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let kind: EntryKind
    let searchText: String
}

enum MaintenanceSupport {
    static let reminderWindowDays = 30

    static func maintenanceCategories(for kind: VehicleKind) -> [MaintenanceCategory] {
        MaintenanceCategory.allCases.filter { $0.isAvailable(for: kind) }
    }

    static func attachments(
        for vehicleID: UUID,
        from attachments: [MaintenanceAttachment]
    ) -> [MaintenanceAttachment] {
        attachments
            .filter { $0.vehicleID == vehicleID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func maintenanceRecords(
        for vehicleID: UUID,
        from records: [MaintenanceRecord]
    ) -> [MaintenanceRecord] {
        records
            .filter { $0.vehicleID == vehicleID }
            .sorted { $0.serviceDate > $1.serviceDate }
    }

    static func documentRecords(
        for vehicleID: UUID,
        from records: [DocumentRecord]
    ) -> [DocumentRecord] {
        records
            .filter { $0.vehicleID == vehicleID }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    static func faultRecords(
        for vehicleID: UUID,
        from records: [FaultRecord]
    ) -> [FaultRecord] {
        records
            .filter { $0.vehicleID == vehicleID }
            .sorted { lhs, rhs in
                if lhs.status.isResolved != rhs.status.isResolved {
                    return !lhs.status.isResolved
                }
                return lhs.discoveredDate > rhs.discoveredDate
            }
    }

    static func dashboardSummary(
        maintenanceRecords: [MaintenanceRecord],
        documents: [DocumentRecord],
        faults: [FaultRecord],
        now: Date = Date()
    ) -> MaintenanceDashboardSummary {
        let upcoming = upcomingReminder(
            maintenanceRecords: maintenanceRecords,
            documents: documents,
            now: now
        )
        let recent = historyEntries(
            maintenanceRecords: maintenanceRecords,
            documents: documents,
            faults: faults
        ).first

        return MaintenanceDashboardSummary(
            upcomingTitle: upcoming?.title ?? "No upcoming items",
            upcomingSubtitle: upcoming.map { relativeDueText(for: $0.dueDate, now: now) } ?? "Add a reminder or expiry date to highlight future work.",
            outstandingFaults: faults.filter { !$0.status.isResolved }.count,
            documentCount: documents.count,
            recentActivityTitle: recent?.title ?? "No recent activity",
            recentActivitySubtitle: recent.map { Formatters.date($0.date) } ?? "Add your first maintenance record, document or fault.",
        )
    }

    static func upcomingReminder(
        maintenanceRecords: [MaintenanceRecord],
        documents: [DocumentRecord],
        now: Date = Date()
    ) -> MaintenanceReminderItem? {
        let items = reminderItems(maintenanceRecords: maintenanceRecords, documents: documents)
            .sorted { $0.dueDate < $1.dueDate }

        return items.first { item in
            let days = Calendar.current.dateComponents([.day], from: now.startOfDay, to: item.dueDate.startOfDay).day ?? 0
            return days <= reminderWindowDays
        } ?? items.first
    }

    static func reminderItems(
        maintenanceRecords: [MaintenanceRecord],
        documents: [DocumentRecord],
        warrantyPlans: [WarrantyPlan] = [],
        vehicleID: UUID? = nil,
        warrantyAvailable: Bool = true
    ) -> [MaintenanceReminderItem] {
        var items: [MaintenanceReminderItem] = []

        for record in maintenanceRecords {
            if let reminderDate = record.reminderDate {
                items.append(
                    MaintenanceReminderItem(
                        id: "maintenance-\(record.id.uuidString)",
                        title: record.title.isEmpty ? record.category.displayName : record.title,
                        dueDate: reminderDate,
                        subtitle: record.category.displayName,
                        kind: .maintenance
                    )
                )
            }
        }

        for document in documents {
            if let reminderDate = document.reminderDate {
                items.append(
                    MaintenanceReminderItem(
                        id: "document-reminder-\(document.id.uuidString)",
                        title: document.title.isEmpty ? document.category.displayName : document.title,
                        dueDate: reminderDate,
                        subtitle: document.category.displayName,
                        kind: .documentReminder
                    )
                )
            }
            if let expiryDate = document.expiryDate {
                items.append(
                    MaintenanceReminderItem(
                        id: "document-expiry-\(document.id.uuidString)",
                        title: document.title.isEmpty ? document.category.displayName : document.title,
                        dueDate: expiryDate,
                        subtitle: "\(document.category.displayName) expiry",
                        kind: .documentExpiry
                    )
                )
            }
        }

        if let vehicleID, warrantyAvailable {
            for warrantyItem in WarrantySupport.reminderItems(plans: warrantyPlans, vehicleID: vehicleID) {
                items.append(
                    MaintenanceReminderItem(
                        id: warrantyItem.id,
                        title: warrantyItem.title,
                        dueDate: warrantyItem.dueDate,
                        subtitle: warrantyItem.subtitle,
                        kind: .warrantyEvent
                    )
                )
            }
        }

        return items
    }

    static func highPriorityFaultCount(_ faults: [FaultRecord]) -> Int {
        faults.filter { !$0.status.isResolved && $0.severity == .high }.count
    }

    static func mediumPriorityFaultCount(_ faults: [FaultRecord]) -> Int {
        faults.filter { !$0.status.isResolved && $0.severity == .medium }.count
    }

    static func lowPriorityFaultCount(_ faults: [FaultRecord]) -> Int {
        faults.filter { !$0.status.isResolved && ($0.severity == .low || $0.severity == .information) }.count
    }

    static func historyEntries(
        maintenanceRecords: [MaintenanceRecord],
        documents: [DocumentRecord],
        faults: [FaultRecord],
        warrantyPlans: [WarrantyPlan] = [],
        ascending: Bool = false
    ) -> [MaintenanceHistoryEntry] {
        var entries: [MaintenanceHistoryEntry] = []

        for record in maintenanceRecords {
            let title = record.title.isEmpty ? record.category.displayName : record.title
            entries.append(
                MaintenanceHistoryEntry(
                    id: "maintenance-\(record.id.uuidString)",
                    date: record.serviceDate,
                    title: title,
                    subtitle: record.category.displayName,
                    kind: .maintenance,
                    searchText: [title, record.category.displayName, record.notes, record.supplier].joined(separator: " ")
                )
            )
        }

        for document in documents {
            let title = document.title.isEmpty ? document.category.displayName : document.title
            entries.append(
                MaintenanceHistoryEntry(
                    id: "document-\(document.id.uuidString)",
                    date: document.dateAdded,
                    title: title,
                    subtitle: document.category.displayName,
                    kind: .document,
                    searchText: [title, document.category.displayName, document.notes].joined(separator: " ")
                )
            )
        }

        for fault in faults {
            let raisedTitle = fault.title.isEmpty ? "Fault raised" : fault.title
            entries.append(
                MaintenanceHistoryEntry(
                    id: "fault-open-\(fault.id.uuidString)",
                    date: fault.discoveredDate,
                    title: raisedTitle,
                    subtitle: "Fault raised",
                    kind: .faultRaised,
                    searchText: [raisedTitle, fault.details, fault.severity.displayName, fault.status.displayName].joined(separator: " ")
                )
            )
            if let resolvedDate = fault.resolvedDate {
                entries.append(
                    MaintenanceHistoryEntry(
                        id: "fault-resolved-\(fault.id.uuidString)",
                        date: resolvedDate,
                        title: raisedTitle,
                        subtitle: "Fault repaired",
                        kind: .faultResolved,
                        searchText: [raisedTitle, fault.details, fault.severity.displayName, fault.status.displayName].joined(separator: " ")
                    )
                )
            }
        }

        for plan in warrantyPlans {
            let manufacturer = plan.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let purchaseSubtitle = manufacturer.isEmpty ? "Warranty plan started" : "\(manufacturer) warranty"
            entries.append(
                MaintenanceHistoryEntry(
                    id: "warranty-purchase-\(plan.id.uuidString)",
                    date: plan.purchaseDate,
                    title: "Warranty purchase",
                    subtitle: purchaseSubtitle,
                    kind: .warrantyPurchase,
                    searchText: ["Warranty purchase", purchaseSubtitle, manufacturer, plan.warrantyType, plan.handbookNotes].joined(separator: " ")
                )
            )

            for event in plan.eventsList {
                let status = WarrantySupport.statusDisplayName(for: WarrantySupport.status(for: event))
                let date = event.completedDate ?? event.scheduledDate
                var subtitleParts = ["Warranty", status]
                if event.isImportantMilestone {
                    subtitleParts.insert("Milestone", at: 1)
                }
                entries.append(
                    MaintenanceHistoryEntry(
                        id: "warranty-event-\(event.id.uuidString)",
                        date: date,
                        title: event.displayTitle,
                        subtitle: subtitleParts.joined(separator: " · "),
                        kind: .warranty,
                        searchText: [
                            event.displayTitle,
                            event.requirementText,
                            status,
                            manufacturer
                        ].joined(separator: " ")
                    )
                )
            }
        }

        return entries.sorted { lhs, rhs in
            if ascending {
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    static func filteredHistoryEntries(
        maintenanceRecords: [MaintenanceRecord],
        documents: [DocumentRecord],
        faults: [FaultRecord],
        warrantyPlans: [WarrantyPlan] = [],
        filter: MaintenanceHistoryFilter,
        searchText: String,
        ascending: Bool = false
    ) -> [MaintenanceHistoryEntry] {
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return historyEntries(
            maintenanceRecords: maintenanceRecords,
            documents: documents,
            faults: faults,
            warrantyPlans: warrantyPlans,
            ascending: ascending
        )
        .filter { entry in
            switch filter {
            case .all:
                break
            case .maintenance:
                guard entry.kind == .maintenance else { return false }
            case .documents:
                guard entry.kind == .document else { return false }
            case .faults:
                guard entry.kind == .faultRaised || entry.kind == .faultResolved else { return false }
            case .warranty:
                guard entry.kind == .warranty || entry.kind == .warrantyPurchase else { return false }
            }
            if normalizedQuery.isEmpty {
                return true
            }
            return entry.searchText.lowercased().contains(normalizedQuery)
        }
    }

    static func relativeDueText(for dueDate: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let dueDay = dueDate.startOfDay
        let today = now.startOfDay
        let dayDelta = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

        if dayDelta < 0 {
            let overdueDays = abs(dayDelta)
            return overdueDays == 1 ? "Overdue by 1 day" : "Overdue by \(overdueDays) days"
        }
        if dayDelta == 0 {
            return "Due today"
        }
        if dayDelta == 1 {
            return "Due in 1 day"
        }
        return "Due in \(dayDelta) days"
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
