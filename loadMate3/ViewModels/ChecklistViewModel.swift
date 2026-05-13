import Combine
import Foundation
import SwiftData

@MainActor
final class ChecklistViewModel: ObservableObject {
    func ensureSeedData(in context: ModelContext, existingSections: [ChecklistSection]) {
        // Insert built-in sections only when the store has none (no UserDefaults gate — it could block
        // forever after a manual section was added before the first seed, or after deleting all sections).
        guard existingSections.isEmpty else { return }
        let descriptor = FetchDescriptor<ChecklistSection>()
        guard let stored = try? context.fetch(descriptor), stored.isEmpty else { return }

        let templates: [(String, Int, [String])] = [
            ("Towing Setup", 0, [
                "Hitch locked",
                "Breakaway cable attached",
                "Lights checked",
                "Mirrors fitted",
            ]),
            ("Pitching", 1, [
                "Levelling completed",
                "Handbrake applied",
                "Electric hookup connected",
            ]),
            ("Departure", 2, [
                "Roof vents closed",
                "Windows secured",
                "Steps stored",
            ]),
        ]

        for (title, order, itemTitles) in templates {
            let section = ChecklistSection(title: title, sortOrder: order)
            context.insert(section)
            for (idx, itemTitle) in itemTitles.enumerated() {
                let item = ChecklistItem(title: itemTitle, isChecked: false, sortOrder: idx, section: section)
                context.insert(item)
            }
        }

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

    func addItem(to section: ChecklistSection, title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let next = (section.items.map(\.sortOrder).max() ?? -1) + 1
        let item = ChecklistItem(title: trimmed, isChecked: false, sortOrder: next, section: section)
        context.insert(item)
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
        for item in section.items {
            item.isChecked = false
        }
        save(context)
    }

    func resetAll(sections: [ChecklistSection], in context: ModelContext) {
        for section in sections {
            for item in section.items {
                item.isChecked = false
            }
        }
        save(context)
    }

    func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
