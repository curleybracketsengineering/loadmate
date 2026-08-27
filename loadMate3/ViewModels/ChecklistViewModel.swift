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
            SyncDebugSeedLog.record("[seed] Checklist template seed skipped — automatic checklist seed disabled; new vehicles get a kind-specific checklist when created")
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

        SyncDebugSeedLog.record("[seed] created checklist template reason = no sections existed")
        SyncDebugSeedLog.record("[seed] Checklist seed skipped — vehicle create is the only seed path")
        appState.didSeedDefaultChecklist = true
        save(context)
    }

    func addSection(
        title: String,
        in context: ModelContext,
        sections: [ChecklistSection],
        profile: VehicleProfile?
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (sections.map(\.sortOrder).max() ?? -1) + 1
        let section = ChecklistSection(title: trimmed, sortOrder: nextOrder, profile: profile)
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
