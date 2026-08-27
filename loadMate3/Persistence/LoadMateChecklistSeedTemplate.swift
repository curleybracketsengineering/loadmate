import Foundation
import SwiftData

/// Factory checklist content shared by automatic seed and the Sync Debug incremental buttons.
enum LoadMateChecklistSeedTemplate {
    struct Group: Equatable {
        let title: String
        let items: [String]
    }

    struct Section: Equatable {
        let title: String
        let templateOrder: Int
        let groups: [Group]

        var itemCount: Int {
            groups.reduce(0) { $0 + $1.items.count }
        }

        var debugButtonTitle: String {
            "Add seed section \(templateOrder + 1) — \(title) (\(itemCount) items)"
        }
    }

    enum InsertResult: Equatable {
        case inserted(title: String, groups: Int, items: Int)
        case skippedAlreadyExists(title: String)
        case skippedNoVehicle
        case invalidIndex

        var logLine: String {
            switch self {
            case .inserted(let title, let groups, let items):
                return "[seed] inserted incremental section \(title) groups=\(groups) items=\(items)"
            case .skippedAlreadyExists(let title):
                return "[seed] skipped incremental section — \(title) already exists"
            case .skippedNoVehicle:
                return "[seed] skipped incremental section — no active vehicle"
            case .invalidIndex:
                return "[seed] skipped incremental section — invalid index"
            }
        }

        var userMessage: String {
            switch self {
            case .inserted(let title, let groups, let items):
                return "Inserted \(title) — \(groups) groups, \(items) items. Wait for Export OK on this device and Import OK on the other before adding the next section."
            case .skippedAlreadyExists(let title):
                return "Skipped — \(title) already exists on this vehicle."
            case .skippedNoVehicle:
                return "Skipped — add or select a vehicle first."
            case .invalidIndex:
                return "Skipped — invalid section index."
            }
        }
    }

    static let caravanSections: [Section] = [
        Section(
            title: "Before leaving home",
            templateOrder: 0,
            groups: [
                Group(
                    title: "Water & waste",
                    items: [
                        "Fresh water filler cap closed",
                        "Grey waste valve closed",
                        "Toilet cassette emptied if needed",
                    ]
                ),
                Group(
                    title: "Interior",
                    items: [
                        "Cupboards and lockers latched",
                        "Loose items stowed or secured",
                        "Fridge door locked",
                        "TV and shelves secured",
                    ]
                ),
                Group(
                    title: "Gas & electric",
                    items: [
                        "Gas isolated at cylinder(s)",
                        "Mains hookup cable stowed",
                        "12V systems set for travel",
                    ]
                ),
                Group(
                    title: "Exterior & chassis",
                    items: [
                        "Corner steadies fully raised",
                        "Steps folded and secured",
                        "Windows and roof vents set for travel",
                        "Jockey wheel raised and clamped",
                    ]
                ),
            ]
        ),
        Section(
            title: "Towing setup",
            templateOrder: 1,
            groups: [
                Group(
                    title: "Hitch & safety",
                    items: [
                        "Engage motor mover",
                        "Coupling locked on tow ball",
                        "Breakaway cable attached",
                        "Secondary coupling / chains attached",
                        "Check connection, by winding up",
                    ]
                ),
                Group(
                    title: "Moving off checks",
                    items: [
                        "Lights plug connected and latched",
                        "Lights tested (brake, indicators, fog)",
                        "Tow mirrors fitted and adjusted",
                        "Disconnect motor mover",
                    ]
                ),
            ]
        ),
        Section(
            title: "Pitching",
            templateOrder: 2,
            groups: [
                Group(
                    title: "On site",
                    items: [
                        "Engage motor mover",
                        "Wheels chocked",
                        "Handbrake applied",
                        "Unit levelled side-to-side and fore-aft",
                    ]
                ),
                Group(
                    title: "Services",
                    items: [
                        "Electric hookup connected",
                        "Fresh water connected",
                        "Waste outlet positioned",
                    ]
                ),
                Group(
                    title: "Stability",
                    items: [
                        "Corner steadies lowered",
                        "Steps deployed safely",
                        "Disconnect motor mover",
                    ]
                ),
            ]
        ),
        Section(
            title: "Departure",
            templateOrder: 3,
            groups: [
                Group(
                    title: "Interior",
                    items: [
                        "Cupboards latched",
                        "Loose items packed",
                        "Roof vents positioned for travel",
                    ]
                ),
                Group(
                    title: "Exterior & hitch",
                    items: [
                        "Engage motor mover",
                        "Corner steadies raised",
                        "Steps stored",
                        "All services disconnected and stowed",
                        "Hitch security checks complete",
                    ]
                ),
                Group(
                    title: "Final checks",
                    items: [
                        "Disconnect motor mover",
                        "Wheel nuts visual check",
                        "Lights check",
                        "Last walk-around",
                    ]
                ),
            ]
        ),
        Section(
            title: "EU / Overseas travel checklist",
            templateOrder: 4,
            groups: [
                Group(
                    title: "Legal requirements",
                    items: [
                        "Passport validity checked",
                        "Travel insurance",
                        "GHIC / EHIC card",
                        "UK sticker / identifier",
                        "Reflective jackets",
                        "Warning triangle",
                        "Breathalyser kit (France optional; some still carry)",
                        "Headlight beam deflectors",
                        "Spare bulbs",
                        "Fire extinguisher",
                        "First aid kit",
                    ]
                ),
                Group(
                    title: "Vehicle compliance",
                    items: [
                        "European breakdown cover",
                        "Green card insurance if needed",
                        "Crit'Air sticker (France if required)",
                        "Emission zone registration",
                        "Toll tags / apps configured",
                    ]
                ),
                Group(
                    title: "Navigation & payments",
                    items: [
                        "Offline maps downloaded",
                        "Mobile roaming enabled",
                        "EU charging apps installed",
                        "Currency / cards prepared",
                    ]
                ),
                Group(
                    title: "Ferry / tunnel",
                    items: [
                        "Gas turned off before boarding",
                        "Height / length details available",
                        "Passport ready at border",
                    ]
                ),
            ]
        ),
    ]

    static var motorhomeSections: [Section] {
        let keep: Set<String> = [
            "Before leaving home",
            "Departure",
            "EU / Overseas travel checklist",
        ]
        return caravanSections
            .filter { keep.contains($0.title) }
            .enumerated()
            .map { index, section in
                Section(title: section.title, templateOrder: index, groups: section.groups)
            }
    }

    static func sections(for kind: VehicleKind) -> [Section] {
        switch kind {
        case .caravan: return caravanSections
        case .motorhome: return motorhomeSections
        }
    }

    static var totalItemCount: Int {
        caravanSections.reduce(0) { $0 + $1.itemCount }
    }

    static var motorhomeItemCount: Int {
        motorhomeSections.reduce(0) { $0 + $1.itemCount }
    }

    /// Inserts every factory section for this vehicle's kind. Caller saves.
    @MainActor
    @discardableResult
    static func insertAll(onto profile: VehicleProfile, in context: ModelContext) -> (sections: Int, items: Int) {
        let templates = sections(for: profile.kind)
        var createdItems = 0
        for template in templates {
            createdItems += materialize(
                template,
                sortOrder: template.templateOrder,
                onto: profile,
                in: context
            ).items
        }
        return (templates.count, createdItems)
    }

    /// Inserts one factory section for the vehicle's kind. Skips a title that already exists on that vehicle.
    @MainActor
    @discardableResult
    static func insertSection(
        at index: Int,
        onto profile: VehicleProfile?,
        in context: ModelContext
    ) -> InsertResult {
        guard let profile else {
            let result = InsertResult.skippedNoVehicle
            record(result.logLine)
            return result
        }
        let templates = sections(for: profile.kind)
        guard templates.indices.contains(index) else {
            record(InsertResult.invalidIndex.logLine)
            return .invalidIndex
        }
        let template = templates[index]
        let existing = profile.checklistSectionsList
        if existing.contains(where: { $0.title.caseInsensitiveCompare(template.title) == .orderedSame }) {
            let result = InsertResult.skippedAlreadyExists(title: template.title)
            record(result.logLine)
            return result
        }
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let created = materialize(template, sortOrder: nextOrder, onto: profile, in: context)
        _ = SyncDebugSaveHelper.save(context, source: "LoadMateChecklistSeedTemplate.insertSection")
        let result = InsertResult.inserted(
            title: template.title,
            groups: created.groups,
            items: created.items
        )
        record(result.logLine)
        return result
    }

    @MainActor
    private static func materialize(
        _ template: Section,
        sortOrder: Int,
        onto profile: VehicleProfile,
        in context: ModelContext
    ) -> (groups: Int, items: Int) {
        let section = ChecklistSection(title: template.title, sortOrder: sortOrder, profile: profile)
        context.insert(section)
        var itemCount = 0
        for (groupIndex, groupSeed) in template.groups.enumerated() {
            let group = ChecklistGroup(title: groupSeed.title, sortOrder: groupIndex, section: section)
            context.insert(group)
            for (itemIndex, itemTitle) in groupSeed.items.enumerated() {
                let item = ChecklistItem(
                    title: itemTitle,
                    isChecked: false,
                    sortOrder: itemIndex,
                    group: group
                )
                context.insert(item)
                itemCount += 1
            }
        }
        return (template.groups.count, itemCount)
    }

    @MainActor
    private static func record(_ message: String) {
        SyncDebugSeedLog.record(message)
    }
}
