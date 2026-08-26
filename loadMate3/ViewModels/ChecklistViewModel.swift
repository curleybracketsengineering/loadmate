import Combine
import Foundation
import SwiftData

@MainActor
final class ChecklistViewModel: ObservableObject {
    /// Moves old flat `section.items` into a `ChecklistGroup` so every row lives under section → group → item.
    func migrateLegacyChecklistIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<ChecklistSection>()
        guard let allSections = try? context.fetch(descriptor) else { return }

        var didChange = false
        for section in allSections {
            let legacy = section.itemsList.filter { $0.group == nil }
            guard !legacy.isEmpty else { continue }
            didChange = true

            if section.groupsList.isEmpty {
                let group = ChecklistGroup(title: "Checklist", sortOrder: 0, section: section)
                context.insert(group)
                for (idx, item) in legacy.enumerated() {
                    item.section = nil
                    item.group = group
                    item.sortOrder = idx
                }
            } else {
                let nextOrder = (section.groupsList.map(\.sortOrder).max() ?? -1) + 1
                let group = ChecklistGroup(title: "Imported", sortOrder: nextOrder, section: section)
                context.insert(group)
                for (idx, item) in legacy.enumerated() {
                    item.section = nil
                    item.group = group
                    item.sortOrder = idx
                }
            }
        }

        if didChange {
            save(context)
            SyncDebugLogger.shared.record(
                category: "startup",
                message: "[migration] moved legacy checklist items into a ChecklistGroup"
            )
        }
    }

    func ensureSeedData(
        in context: ModelContext,
        existingSections: [ChecklistSection],
        appState: AppState
    ) {
        StartupCensus.log("checklist before seed/migration", in: context)
        defer { StartupCensus.log("checklist after seed/migration", in: context) }
        if !LoadMateSeedPolicy.automaticVehicleAndChecklistSeedEnabled {
            SyncDebugSeedLog.record("[seed] Checklist template seed skipped — automatic checklist seed disabled")
            return
        }
        if SyncDebugSeedIsolation.isAutomaticSeedingSuppressed {
            SyncDebugSeedLog.record("[seed] Automatic checklist seed suppressed (developer diagnostic)")
            return
        }
        guard !appState.didSeedDefaultChecklist else {
            SyncDebugSeedLog.record("[seed] Checklist seed skipped — already flagged as seeded")
            return
        }
        // Insert built-in sections only when the store has none (no UserDefaults gate — it could block
        // forever after a manual section was added before the first seed, or after deleting all sections).
        guard existingSections.isEmpty else {
            SyncDebugSeedLog.record("[seed] Checklist seed skipped — \(existingSections.count) section(s) already exist")
            return
        }
        let descriptor = FetchDescriptor<ChecklistSection>()
        guard let stored = try? context.fetch(descriptor), stored.isEmpty else {
            SyncDebugSeedLog.record("[seed] Checklist seed skipped — stored sections already exist")
            return
        }

        typealias SeedGroup = (title: String, items: [String])
        let templates: [(section: String, order: Int, groups: [SeedGroup])] = [
            (
                "Before leaving home",
                0,
                [
                    (
                        "Water & waste",
                        [
                            "Fresh water filler cap closed",
                            "Grey waste valve closed",
                            "Toilet cassette emptied if needed",
                        ],
                    ),
                    (
                        "Interior",
                        [
                            "Cupboards and lockers latched",
                            "Loose items stowed or secured",
                            "Fridge door locked",
                            "TV and shelves secured",
                        ],
                    ),
                    (
                        "Gas & electric",
                        [
                            "Gas isolated at cylinder(s)",
                            "Mains hookup cable stowed",
                            "12V systems set for travel",
                        ],
                    ),
                    (
                        "Exterior & chassis",
                        [
                            "Corner steadies fully raised",
                            "Steps folded and secured",
                            "Windows and roof vents set for travel",
                            "Jockey wheel raised and clamped",
                        ],
                    ),
                ],
            ),
            (
                "Towing setup",
                1,
                [
                    (
                        "Hitch & safety",
                        [
                            "Engage motor mover",
                            "Coupling locked on tow ball",
                            "Breakaway cable attached",
                            "Secondary coupling / chains attached",
                            "Check connection, by winding up",
                        ],
                    ),
                    (
                        "Moving off checks",
                        [
                            "Lights plug connected and latched",
                            "Lights tested (brake, indicators, fog)",
                            "Tow mirrors fitted and adjusted",
                            "Disconnect motor mover",
                        ],
                    ),
                ],
            ),
            (
                "Pitching",
                2,
                [
                    (
                        "On site",
                        [
                            "Engage motor mover",
                            "Wheels chocked",
                            "Handbrake applied",
                            "Unit levelled side-to-side and fore-aft",
                        ],
                    ),
                    (
                        "Services",
                        [
                            "Electric hookup connected",
                            "Fresh water connected",
                            "Waste outlet positioned",
                        ],
                    ),
                    (
                        "Stability",
                        [
                            "Corner steadies lowered",
                            "Steps deployed safely",
                            "Disconnect motor mover",
                        ],
                    ),
                ],
            ),
            (
                "Departure",
                3,
                [
                    (
                        "Interior",
                        [
                            "Cupboards latched",
                            "Loose items packed",
                            "Roof vents positioned for travel",
                        ],
                    ),
                    (
                        "Exterior & hitch",
                        [
                            "Engage motor mover",
                            "Corner steadies raised",
                            "Steps stored",
                            "All services disconnected and stowed",
                            "Hitch security checks complete",
                        ],
                    ),
                    (
                        "Final checks",
                        [
                            "Disconnect motor mover",
                            "Wheel nuts visual check",
                            "Lights check",
                            "Last walk-around",
                        ],
                    ),
                ],
            ),
            (
                "EU / Overseas travel checklist",
                4,
                [
                    (
                        "Legal requirements",
                        [
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
                        ],
                    ),
                    (
                        "Vehicle compliance",
                        [
                            "European breakdown cover",
                            "Green card insurance if needed",
                            "Crit'Air sticker (France if required)",
                            "Emission zone registration",
                            "Toll tags / apps configured",
                        ],
                    ),
                    (
                        "Navigation & payments",
                        [
                            "Offline maps downloaded",
                            "Mobile roaming enabled",
                            "EU charging apps installed",
                            "Currency / cards prepared",
                        ],
                    ),
                    (
                        "Ferry / tunnel",
                        [
                            "Gas turned off before boarding",
                            "Height / length details available",
                            "Passport ready at border",
                        ],
                    ),
                ],
            ),
        ]

        SyncDebugSeedLog.record("[seed] created checklist template reason = no sections existed")
        var createdSections = 0
        var createdItems = 0
        for template in templates {
            let section = ChecklistSection(title: template.section, sortOrder: template.order)
            context.insert(section)
            createdSections += 1
            for (gIdx, groupSeed) in template.groups.enumerated() {
                let group = ChecklistGroup(title: groupSeed.title, sortOrder: gIdx, section: section)
                context.insert(group)
                for (iIdx, itemTitle) in groupSeed.items.enumerated() {
                    let item = ChecklistItem(title: itemTitle, isChecked: false, sortOrder: iIdx, group: group)
                    context.insert(item)
                    createdItems += 1
                }
            }
        }

        appState.didSeedDefaultChecklist = true
        SyncDebugSeedLog.record("[seed] Created \(createdSections) checklist sections / \(createdItems) checklist items")
        save(context)
    }

    func addSection(title: String, in context: ModelContext, sections: [ChecklistSection]) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (sections.map(\.sortOrder).max() ?? -1) + 1
        let section = ChecklistSection(title: trimmed, sortOrder: nextOrder)
        context.insert(section)
        save(context)
    }

    func renameSection(_ section: ChecklistSection, to newTitle: String, in context: ModelContext) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        section.title = trimmed
        save(context)
    }

    func deleteSection(_ section: ChecklistSection, in context: ModelContext) {
        context.delete(section)
        save(context)
    }

    func addGroup(to section: ChecklistSection, title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let next = (section.groupsList.map(\.sortOrder).max() ?? -1) + 1
        let group = ChecklistGroup(title: trimmed, sortOrder: next, section: section)
        context.insert(group)
        save(context)
    }

    func renameGroup(_ group: ChecklistGroup, to newTitle: String, in context: ModelContext) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        group.title = trimmed
        save(context)
    }

    func deleteGroup(_ group: ChecklistGroup, in context: ModelContext) {
        context.delete(group)
        save(context)
    }

    func addItem(to group: ChecklistGroup, title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let next = (group.itemsList.map(\.sortOrder).max() ?? -1) + 1
        let item = ChecklistItem(title: trimmed, isChecked: false, sortOrder: next, group: group)
        context.insert(item)
        save(context)
    }

    func renameItem(_ item: ChecklistItem, to newTitle: String, in context: ModelContext) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        save(context)
    }

    func deleteItem(_ item: ChecklistItem, in context: ModelContext) {
        context.delete(item)
        save(context)
    }

    func setChecked(_ item: ChecklistItem, _ checked: Bool, in context: ModelContext) {
        item.isChecked = checked
        save(context)
    }

    func resetSection(_ section: ChecklistSection, in context: ModelContext) {
        for group in section.groupsList {
            for item in group.itemsList {
                item.isChecked = false
            }
        }
        for item in section.itemsList {
            item.isChecked = false
        }
        save(context)
    }

    func resetAll(sections: [ChecklistSection], in context: ModelContext) {
        for section in sections {
            for group in section.groupsList {
                for item in group.itemsList {
                    item.isChecked = false
                }
            }
            for item in section.itemsList {
                item.isChecked = false
            }
        }
        save(context)
    }

    func save(_ context: ModelContext) {
        _ = SyncDebugSaveHelper.save(context, source: "ChecklistViewModel.save")
    }
}
