import Foundation
import SwiftData

enum ChecklistStore {
    static func sections(for profile: VehicleProfile?, from all: [ChecklistSection]) -> [ChecklistSection] {
        guard let profile else { return [] }
        return all
            .filter { $0.profile?.id == profile.id }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
}

enum ChecklistVehicleMigration {
    /// Copies unscoped (pre-relationship) checklists onto every vehicle that has none, then deletes the originals.
    @MainActor
    static func migrateIfNeeded(in context: ModelContext, appState: AppState, profiles: [VehicleProfile]) {
        guard !appState.didMigrateChecklistsToVehicles else { return }

        let allSections = (try? context.fetch(FetchDescriptor<ChecklistSection>())) ?? []
        let unscoped = allSections.filter { $0.profile == nil }

        var didChange = false
        for profile in profiles where profile.checklistSectionsList.isEmpty {
            guard !unscoped.isEmpty else { continue }
            deepCopy(unscoped, onto: profile, in: context)
            didChange = true
            SyncDebugSeedLog.record(
                "[migration] copied unscoped checklist onto vehicle id=\(profile.id.uuidString) sections=\(unscoped.count)"
            )
        }

        for section in unscoped {
            context.delete(section)
            didChange = true
        }

        appState.didMigrateChecklistsToVehicles = true
        if didChange {
            SyncDebugSeedLog.record("[migration] checklist-to-vehicle copy complete; unscoped originals deleted")
            _ = SyncDebugSaveHelper.save(context, source: "ChecklistVehicleMigration.migrateIfNeeded")
        } else {
            _ = SyncDebugSaveHelper.save(context, source: "ChecklistVehicleMigration.migrateIfNeeded")
        }
    }

    /// Drops trailer-only factory rows from existing motorhomes and adds vehicle checks if missing.
    @MainActor
    static func patchMotorhomeFactoryItemsIfNeeded(in context: ModelContext, profiles: [VehicleProfile]) {
        var didChange = false
        for profile in profiles where profile.kind == .motorhome {
            if patchMotorhomeFactoryItems(on: profile, in: context) {
                didChange = true
            }
        }
        guard didChange else { return }
        SyncDebugSeedLog.record("[migration] patched motorhome checklist factory items")
        _ = SyncDebugSaveHelper.save(context, source: "ChecklistVehicleMigration.patchMotorhomeFactoryItemsIfNeeded")
    }

    /// Drops motorhome-only factory rows from existing caravans and adds tow-car checks if missing.
    @MainActor
    static func patchCaravanFactoryItemsIfNeeded(in context: ModelContext, profiles: [VehicleProfile]) {
        var didChange = false
        for profile in profiles where profile.kind == .caravan {
            if patchCaravanFactoryItems(on: profile, in: context) {
                didChange = true
            }
        }
        guard didChange else { return }
        SyncDebugSeedLog.record("[migration] patched caravan checklist factory items")
        _ = SyncDebugSaveHelper.save(context, source: "ChecklistVehicleMigration.patchCaravanFactoryItemsIfNeeded")
    }

    @MainActor
    @discardableResult
    static func patchMotorhomeFactoryItems(on profile: VehicleProfile, in context: ModelContext) -> Bool {
        guard profile.kind == .motorhome else { return false }

        var didChange = false
        let excludedItems = LoadMateChecklistSeedTemplate.motorhomeExcludedItemTitles
        let remaps = LoadMateChecklistSeedTemplate.motorhomeItemTitleRemaps
        let excludedSections = LoadMateChecklistSeedTemplate.motorhomeExcludedSectionTitles

        for section in profile.checklistSectionsList {
            for group in section.groupsList {
                let groupTitles = Set(group.itemsList.map(\.title))
                for item in group.itemsList {
                    if let renamed = remaps[item.title] {
                        if groupTitles.contains(renamed) {
                            context.delete(item)
                        } else {
                            item.title = renamed
                        }
                        didChange = true
                    } else if excludedItems.contains(item.title) {
                        context.delete(item)
                        didChange = true
                    }
                }
            }
        }

        for section in profile.checklistSectionsList {
            for group in section.groupsList where group.itemsList.isEmpty {
                context.delete(group)
                didChange = true
            }
        }

        for section in profile.checklistSectionsList where excludedSections.contains(where: {
            $0.caseInsensitiveCompare(section.title) == .orderedSame
        }) {
            context.delete(section)
            didChange = true
        }

        if let pitching = profile.checklistSectionsList.first(where: {
            $0.title.caseInsensitiveCompare("Pitching") == .orderedSame
        }) {
            if profile.checklistSectionsList.contains(where: {
                $0.title.caseInsensitiveCompare("On site") == .orderedSame
            }) {
                context.delete(pitching)
                didChange = true
            } else {
                pitching.title = "On site"
                didChange = true
            }
        }

        if let beforeLeaving = profile.checklistSectionsList.first(where: {
            $0.title.caseInsensitiveCompare("Before leaving home") == .orderedSame
        }) {
            didChange = renameGroupIfNeeded(
                titled: "Exterior & chassis",
                to: "Exterior",
                in: beforeLeaving
            ) || didChange
            didChange = ensureGroup(
                LoadMateChecklistSeedTemplate.motorhomeVehicleGroup,
                in: beforeLeaving,
                context: context
            ) || didChange
        }

        if let departure = profile.checklistSectionsList.first(where: {
            $0.title.caseInsensitiveCompare("Departure") == .orderedSame
        }) {
            didChange = renameGroupIfNeeded(
                titled: "Exterior & hitch",
                to: "Exterior",
                in: departure
            ) || didChange
        }

        return didChange
    }

    @MainActor
    @discardableResult
    static func patchCaravanFactoryItems(on profile: VehicleProfile, in context: ModelContext) -> Bool {
        guard profile.kind == .caravan else { return false }

        var didChange = false
        let excludedItems = LoadMateChecklistSeedTemplate.caravanExcludedItemTitles

        for section in profile.checklistSectionsList {
            for group in section.groupsList {
                for item in group.itemsList where excludedItems.contains(item.title) {
                    context.delete(item)
                    didChange = true
                }
            }
        }

        for section in profile.checklistSectionsList {
            for group in section.groupsList where group.itemsList.isEmpty {
                context.delete(group)
                didChange = true
            }
        }

        if let beforeLeaving = profile.checklistSectionsList.first(where: {
            $0.title.caseInsensitiveCompare("Before leaving home") == .orderedSame
        }) {
            didChange = renameGroupIfNeeded(
                titled: "Vehicle",
                to: LoadMateChecklistSeedTemplate.caravanTowCarGroup.title,
                in: beforeLeaving
            ) || didChange
            didChange = ensureGroup(
                LoadMateChecklistSeedTemplate.caravanTowCarGroup,
                in: beforeLeaving,
                context: context
            ) || didChange
        }

        return didChange
    }

    @MainActor
    private static func ensureGroup(
        _ seed: LoadMateChecklistSeedTemplate.Group,
        in section: ChecklistSection,
        context: ModelContext
    ) -> Bool {
        var didChange = false
        let group: ChecklistGroup
        if let existing = existingGroup(titled: seed.title, in: section) {
            group = existing
        } else {
            let nextOrder = (section.groupsList.map(\.sortOrder).max() ?? -1) + 1
            let created = ChecklistGroup(title: seed.title, sortOrder: nextOrder, section: section)
            context.insert(created)
            group = created
            didChange = true
        }

        let existingTitles = Set(group.itemsList.map(\.title))
        var nextItemOrder = (group.itemsList.map(\.sortOrder).max() ?? -1) + 1
        for title in seed.items where !existingTitles.contains(title) {
            let item = ChecklistItem(
                title: title,
                isChecked: false,
                sortOrder: nextItemOrder,
                group: group
            )
            context.insert(item)
            nextItemOrder += 1
            didChange = true
        }
        return didChange
    }

    @discardableResult
    private static func renameGroupIfNeeded(titled oldTitle: String, to newTitle: String, in section: ChecklistSection) -> Bool {
        guard let group = existingGroup(titled: oldTitle, in: section) else { return false }
        guard existingGroup(titled: newTitle, in: section) == nil else { return false }
        group.title = newTitle
        return true
    }

    private static func existingGroup(titled title: String, in section: ChecklistSection) -> ChecklistGroup? {
        section.groupsList.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }

    @MainActor
    static func deepCopy(
        _ sources: [ChecklistSection],
        onto profile: VehicleProfile,
        in context: ModelContext
    ) {
        for source in sources.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let section = ChecklistSection(
                title: source.title,
                sortOrder: source.sortOrder,
                profile: profile
            )
            context.insert(section)
            for group in source.groupsList.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let copiedGroup = ChecklistGroup(
                    title: group.title,
                    sortOrder: group.sortOrder,
                    section: section
                )
                context.insert(copiedGroup)
                for item in group.itemsList.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    let copiedItem = ChecklistItem(
                        title: item.title,
                        isChecked: item.isChecked,
                        sortOrder: item.sortOrder,
                        group: copiedGroup
                    )
                    context.insert(copiedItem)
                }
            }
            let legacy = source.itemsList.filter { $0.group == nil }.sorted { $0.sortOrder < $1.sortOrder }
            if !legacy.isEmpty {
                let imported = ChecklistGroup(title: "Imported", sortOrder: section.groupsList.count, section: section)
                context.insert(imported)
                for (index, item) in legacy.enumerated() {
                    let copiedItem = ChecklistItem(
                        title: item.title,
                        isChecked: item.isChecked,
                        sortOrder: index,
                        group: imported
                    )
                    context.insert(copiedItem)
                }
            }
        }
    }
}
