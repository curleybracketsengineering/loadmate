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
        case invalidIndex

        var logLine: String {
            switch self {
            case .inserted(let title, let groups, let items):
                return "[seed] inserted incremental section \(title) groups=\(groups) items=\(items)"
            case .skippedAlreadyExists(let title):
                return "[seed] skipped incremental section — \(title) already exists"
            case .invalidIndex:
                return "[seed] skipped incremental section — invalid index"
            }
        }

        var userMessage: String {
            switch self {
            case .inserted(let title, let groups, let items):
                return "Inserted \(title) — \(groups) groups, \(items) items. Wait for Export OK on this device and Import OK on the other before adding the next section."
            case .skippedAlreadyExists(let title):
                return "Skipped — \(title) already exists."
            case .invalidIndex:
                return "Skipped — invalid section index."
            }
        }
    }

    static let sections: [Section] = [
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

    static var totalItemCount: Int {
        sections.reduce(0) { $0 + $1.itemCount }
    }

    /// Inserts every factory section using template sort order. Caller saves.
    @MainActor
    @discardableResult
    static func insertAll(in context: ModelContext) -> (sections: Int, items: Int) {
        var createdItems = 0
        for template in sections {
            createdItems += materialize(template, sortOrder: template.templateOrder, in: context).items
        }
        return (sections.count, createdItems)
    }

    /// Inserts one factory section after existing rows. Does not set `didSeedDefaultChecklist`.
    @MainActor
    @discardableResult
    static func insertSection(at index: Int, in context: ModelContext) -> InsertResult {
        guard sections.indices.contains(index) else {
            record(InsertResult.invalidIndex.logLine)
            return .invalidIndex
        }
        let template = sections[index]
        let existing = (try? context.fetch(FetchDescriptor<ChecklistSection>())) ?? []
        if existing.contains(where: { $0.title.caseInsensitiveCompare(template.title) == .orderedSame }) {
            let result = InsertResult.skippedAlreadyExists(title: template.title)
            record(result.logLine)
            return result
        }
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let created = materialize(template, sortOrder: nextOrder, in: context)
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
        in context: ModelContext
    ) -> (groups: Int, items: Int) {
        let section = ChecklistSection(title: template.title, sortOrder: sortOrder)
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
