import Foundation
import Combine
import SwiftData

@MainActor
final class LoadViewModel: ObservableObject {
    func load(item: LibraryItem, loadedItems: [LoadedItem], in context: ModelContext) {
        if let existing = loadedItems.first(where: { $0.item?.id == item.id }) {
            existing.quantity += 1
            if existing.zone == .unassigned, let defaultZone = item.defaultZone {
                existing.zone = defaultZone
            }
        } else {
            let zone = item.defaultZone ?? .unassigned
            context.insert(LoadedItem(item: item, quantity: 1, zone: zone))
        }
        save(context)
    }

    func unload(item: LibraryItem, loadedItems: [LoadedItem], in context: ModelContext) {
        guard let existing = loadedItems.first(where: { $0.item?.id == item.id }) else { return }
        if existing.quantity <= 1 {
            context.delete(existing)
        } else {
            existing.quantity -= 1
        }
        save(context)
    }

    func delete(item: LibraryItem, loadedItems: [LoadedItem], in context: ModelContext) {
        loadedItems.filter { $0.item?.id == item.id }.forEach(context.delete)
        context.delete(item)
        save(context)
    }

    func addLibraryItem(name: String, weightKg: Double, in context: ModelContext) {
        context.insert(LibraryItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines), weightKg: weightKg))
        save(context)
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
