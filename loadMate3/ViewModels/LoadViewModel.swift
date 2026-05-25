import Foundation
import Combine
import SwiftData

@MainActor
final class LoadViewModel: ObservableObject {
    func load(
        item: LibraryItem,
        trip: Trip?,
        loadedItems: [LoadedItem],
        in context: ModelContext
    ) {
        let kind = trip?.profile?.kind ?? .caravan
        let rawDefault = item.defaultZone ?? .unassigned
        let zone = rawDefault.defaultForLoading(on: kind)
        context.insert(LoadedItem(item: item, quantity: 1, zone: zone, trip: trip))
        save(context)
    }

    func unload(item: LibraryItem, loadedItems: [LoadedItem], in context: ModelContext) {
        let rows = loadedItems.filter { $0.item?.id == item.id }
        guard !rows.isEmpty else { return }
        let sorted = rows.sorted { $0.loadedAt > $1.loadedAt }
        guard let target = sorted.first else { return }
        if target.quantity > 1 {
            target.quantity -= 1
        } else {
            context.delete(target)
        }
        save(context)
    }

    func delete(item: LibraryItem, allLoadedItems: [LoadedItem], in context: ModelContext) {
        allLoadedItems.filter { $0.item?.id == item.id }.forEach(context.delete)
        context.delete(item)
        save(context)
    }

    func addLibraryItem(name: String, weightKg: Double, in context: ModelContext) {
        context.insert(LibraryItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines), weightKg: weightKg))
        save(context)
    }

    func updateLibraryItem(_ item: LibraryItem, name: String, weightKg: Double, in context: ModelContext) {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.weightKg = weightKg
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
