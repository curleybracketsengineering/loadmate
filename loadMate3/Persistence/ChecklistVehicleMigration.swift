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

    @MainActor
    @discardableResult
    static func patchMotorhomeFactoryItems(on profile: VehicleProfile, in context: ModelContext) -> Bool {
        guard profile.kind == .motorhome else { return false }

        var didChange = false
        let excluded = LoadMateChecklistSeedTemplate.motorhomeExcludedItemTitles

        for section in profile.checklistSectionsList {
            for group in section.groupsList {
                for item in group.itemsList where excluded.contains(item.title) {
                    context.delete(item)
                    didChange = true
                }
            }
        }

        if let beforeLeaving = profile.checklistSectionsList.first(where: {
            $0.title.caseInsensitiveCompare("Before leaving home") == .orderedSame
        }) {
            let vehicleTitle = LoadMateChecklistSeedTemplate.motorhomeVehicleGroup.title
            let vehicleGroup: ChecklistGroup
            if let existing = existingGroup(titled: vehicleTitle, in: beforeLeaving) {
                vehicleGroup = existing
            } else {
                let nextOrder = (beforeLeaving.groupsList.map(\.sortOrder).max() ?? -1) + 1
                let group = ChecklistGroup(title: vehicleTitle, sortOrder: nextOrder, section: beforeLeaving)
                context.insert(group)
                vehicleGroup = group
                didChange = true
            }

            let existingTitles = Set(vehicleGroup.itemsList.map(\.title))
            var nextItemOrder = (vehicleGroup.itemsList.map(\.sortOrder).max() ?? -1) + 1
            for title in LoadMateChecklistSeedTemplate.motorhomeVehicleGroup.items where !existingTitles.contains(title) {
                let item = ChecklistItem(
                    title: title,
                    isChecked: false,
                    sortOrder: nextItemOrder,
                    group: vehicleGroup
                )
                context.insert(item)
                nextItemOrder += 1
                didChange = true
            }
        }

        return didChange
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
