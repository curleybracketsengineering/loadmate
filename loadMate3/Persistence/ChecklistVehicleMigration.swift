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
