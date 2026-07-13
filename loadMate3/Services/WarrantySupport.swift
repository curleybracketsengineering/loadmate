import Foundation

struct WarrantyTemplateOption: Identifiable {
    let id: String
    let displayName: String
    let manufacturer: String
}

struct WarrantyReminderItem: Identifiable {
    let id: String
    let title: String
    let dueDate: Date
    let subtitle: String
    let eventID: UUID
}

enum WarrantySupport {
    static let defaultDurationYears = 8
    static let defaultDaysBefore = 60
    static let defaultDaysAfter = 30

    /// Starter statutory inspection schedule for non-UK motorhomes (confirm local rules).
    static let motorhomeVehicleInspectionFirstYear = 3
    static let motorhomeVehicleInspectionDaysBefore = 30
    static let motorhomeVehicleInspectionDaysAfter = 0

    static func suggestedMOTClass(for profile: VehicleProfile) -> UKMotorhomeMOTClass {
        UKMotorhomeMOTClass.suggested(forPlatedMassKg: profile.mtplmKg)
    }

    static let warrantyDisclaimer = """
    LoadMate helps you organise warranty-related records and reminders. It cannot confirm warranty coverage, interpret manufacturer terms, or guarantee that a claim will be accepted. Always follow your owner's handbook and manufacturer instructions. If in doubt, contact your dealer or manufacturer directly.
    """

    static let customTemplateID = WarrantyPatternCatalog.customID

    static let starterDisclaimer = WarrantyPatternCatalog.starterDisclaimer

    static let templateOptions: [WarrantyTemplateOption] = {
        WarrantyPatternCatalog.pickerOptions.map {
            WarrantyTemplateOption(
                id: $0.id,
                displayName: $0.displayName,
                manufacturer: $0.manufacturerName
            )
        }
    }()

    static func patternOrCustom(id: String?, kind: VehicleKind) -> WarrantyManufacturerTemplate {
        switch kind {
        case .caravan:
            return WarrantyPatternCatalog.patternOrCustom(id: id)
        case .motorhome:
            return MotorhomeWarrantyPatternCatalog.patternOrCustom(id: id)
        }
    }

    static func patternSummary(for templateID: String?, kind: VehicleKind) -> String {
        patternOrCustom(id: templateID, kind: kind).summary
    }

    static func manufacturerTemplate(for templateID: String?, kind: VehicleKind) -> WarrantyManufacturerTemplate? {
        let template = patternOrCustom(id: templateID, kind: kind)
        return template.isCustom ? nil : template
    }

    static func showsWarrantyFeatures(for profile: VehicleProfile?) -> Bool {
        profile?.warrantyAvailable ?? true
    }

    static func usesUKManufacturerStarters(for profile: VehicleProfile?) -> Bool {
        (profile?.warrantyAvailable ?? true) && (profile?.warrantyUKMarket ?? true)
    }

    static func pickerOptions(for profile: VehicleProfile?) -> [WarrantyManufacturerTemplate] {
        let kind = profile?.kind ?? .caravan
        if usesUKManufacturerStarters(for: profile) {
            switch kind {
            case .caravan:
                return WarrantyPatternCatalog.pickerOptions
            case .motorhome:
                return MotorhomeWarrantyPatternCatalog.pickerOptions
            }
        }
        return [patternOrCustom(id: customTemplateID, kind: kind)]
    }

    static func plan(for vehicleID: UUID, from plans: [WarrantyPlan]) -> WarrantyPlan? {
        plans.first { $0.vehicleID == vehicleID }
    }

    static func events(for vehicleID: UUID, from plans: [WarrantyPlan]) -> [WarrantyEvent] {
        plan(for: vehicleID, from: plans)?.eventsList ?? []
    }

    static func expiresOn(plan: WarrantyPlan) -> Date? {
        if let expiry = plan.warrantyExpiryDate {
            return expiry
        }
        return Calendar.current.date(byAdding: .year, value: plan.durationYears, to: plan.purchaseDate)
    }

    static func isCoverageActive(plan: WarrantyPlan, now: Date = Date()) -> Bool {
        guard plan.isUnderWarranty else { return false }
        guard let expiry = expiresOn(plan: plan) else { return plan.isUnderWarranty }
        return now.startOfDay <= expiry.startOfDay
    }

    static func coverageStatusText(plan: WarrantyPlan?, now: Date = Date()) -> (title: String, detail: String, tintIsPositive: Bool) {
        guard let plan else {
            return ("Warranty not configured", "Set up a personalised warranty plan for this vehicle.", false)
        }

        if !plan.isUnderWarranty {
            return ("Not under warranty", "You have marked this vehicle as not under warranty.", false)
        }

        if isCoverageActive(plan: plan, now: now), let expiry = expiresOn(plan: plan) {
            return (
                "Under warranty",
                "Coverage recorded until \(Formatters.date(expiry)).",
                true
            )
        }

        if let expiry = expiresOn(plan: plan) {
            return (
                "Warranty expired",
                "Recorded coverage ended on \(Formatters.date(expiry)).",
                false
            )
        }

        return ("Under warranty", "Coverage status recorded for this vehicle.", true)
    }

    static func windowStart(for event: WarrantyEvent) -> Date {
        Calendar.current.date(byAdding: .day, value: -event.daysBefore, to: event.scheduledDate.startOfDay) ?? event.scheduledDate
    }

    static func windowEnd(for event: WarrantyEvent) -> Date {
        Calendar.current.date(byAdding: .day, value: event.daysAfter, to: event.scheduledDate.startOfDay) ?? event.scheduledDate
    }

    static func status(for event: WarrantyEvent, now: Date = Date()) -> WarrantyEventStatus {
        if event.completedDate != nil {
            return .completed
        }

        let today = now.startOfDay
        let windowStart = windowStart(for: event).startOfDay
        let windowEnd = windowEnd(for: event).startOfDay
        let scheduled = event.scheduledDate.startOfDay

        if today > windowEnd {
            return .overdue
        }
        if today >= windowStart && today <= windowEnd {
            return .inWindow
        }
        if today > scheduled {
            return .overdue
        }
        return .upcoming
    }

    static func statusDisplayName(for status: WarrantyEventStatus) -> String {
        switch status {
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .inWindow: return "In window"
        case .upcoming: return "Upcoming"
        }
    }

    static func windowSubtitle(for event: WarrantyEvent) -> String {
        "Action window: \(event.daysBefore) days before – \(event.daysAfter) days after due date"
    }

    static func reminderDate(for event: WarrantyEvent) -> Date {
        windowStart(for: event)
    }

    static func reminderItems(
        plans: [WarrantyPlan],
        vehicleID: UUID,
        now: Date = Date()
    ) -> [WarrantyReminderItem] {
        guard let plan = plan(for: vehicleID, from: plans), plan.isUnderWarranty else {
            return []
        }

        return plan.eventsList.compactMap { event in
            guard event.completedDate == nil else { return nil }
            let reminderDate = reminderDate(for: event)
            return WarrantyReminderItem(
                id: "warranty-\(event.id.uuidString)",
                title: event.displayTitle,
                dueDate: reminderDate,
                subtitle: event.requirementText,
                eventID: event.id
            )
        }
        .sorted { $0.dueDate < $1.dueDate }
    }

    static func nextActionableEvent(
        plans: [WarrantyPlan],
        vehicleID: UUID,
        now: Date = Date()
    ) -> WarrantyEvent? {
        guard let plan = plan(for: vehicleID, from: plans) else { return nil }

        let openEvents = plan.eventsList.filter { $0.completedDate == nil }
        let inWindow = openEvents.filter { status(for: $0, now: now) == .inWindow }
        if let next = inWindow.sorted(by: { $0.scheduledDate < $1.scheduledDate }).first {
            return next
        }

        let overdue = openEvents.filter { status(for: $0, now: now) == .overdue }
        if let next = overdue.sorted(by: { $0.scheduledDate < $1.scheduledDate }).first {
            return next
        }

        return openEvents
            .sorted { reminderDate(for: $0) < reminderDate(for: $1) }
            .first
    }

    static func careHubSubtitle(
        plans: [WarrantyPlan],
        vehicleID: UUID,
        now: Date = Date()
    ) -> String {
        guard let plan = plan(for: vehicleID, from: plans) else {
            return "Set up your personalised warranty plan."
        }

        if let event = nextActionableEvent(plans: plans, vehicleID: vehicleID, now: now) {
            let eventStatus = status(for: event, now: now)
            switch eventStatus {
            case .inWindow:
                return "\(event.displayTitle) is in its action window now."
            case .overdue:
                return "\(event.displayTitle) is overdue — review your warranty plan."
            case .upcoming:
                return "Next: \(event.displayTitle) · \(MaintenanceSupport.relativeDueText(for: reminderDate(for: event), now: now))."
            case .completed:
                break
            }
        }

        let coverage = coverageStatusText(plan: plan, now: now)
        return coverage.detail
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
