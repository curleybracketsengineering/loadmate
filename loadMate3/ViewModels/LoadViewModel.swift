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

    /// Adds typical caravan library items and loads any not yet on the trip (merge; keeps existing names/weights).
    @discardableResult
    func applyCaravanStarterKit(
        trip: Trip?,
        libraryItems: [LibraryItem],
        loadedItems: [LoadedItem],
        in context: ModelContext
    ) -> Int {
        applyStarterKit(
            entries: CaravanStarterKit.entries.map { ($0.name, $0.weightKg, $0.zone, $0.quantity) },
            kind: .caravan,
            normalizedName: CaravanStarterKit.normalizedName,
            trip: trip,
            libraryItems: libraryItems,
            loadedItems: loadedItems,
            in: context
        )
    }

    /// Adds typical motorhome library items and loads any not yet on the trip (merge; keeps existing names/weights).
    @discardableResult
    func applyMotorhomeStarterKit(
        trip: Trip?,
        libraryItems: [LibraryItem],
        loadedItems: [LoadedItem],
        in context: ModelContext
    ) -> Int {
        applyStarterKit(
            entries: MotorhomeStarterKit.entries.map { ($0.name, $0.weightKg, $0.zone, $0.quantity) },
            kind: .motorhome,
            normalizedName: MotorhomeStarterKit.normalizedName,
            trip: trip,
            libraryItems: libraryItems,
            loadedItems: loadedItems,
            in: context
        )
    }

    @discardableResult
    private func applyStarterKit(
        entries: [(name: String, weightKg: Double, zone: LoadZone, quantity: Int)],
        kind: VehicleKind,
        normalizedName: (String) -> String,
        trip: Trip?,
        libraryItems: [LibraryItem],
        loadedItems: [LoadedItem],
        in context: ModelContext
    ) -> Int {
        guard let trip, trip.profile?.kind == kind else { return 0 }

        var itemsByName = Dictionary(
            libraryItems.map { (normalizedName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var addedToTrip = 0

        for entry in entries {
            let key = normalizedName(entry.name)
            let item: LibraryItem
            if let existing = itemsByName[key] {
                item = existing
            } else {
                let created = LibraryItem(
                    name: entry.name,
                    weightKg: entry.weightKg,
                    defaultZoneRaw: entry.zone.rawValue
                )
                context.insert(created)
                itemsByName[key] = created
                item = created
            }

            let onTrip = loadedItems
                .filter { $0.item?.id == item.id && $0.trip?.id == trip.id }
                .reduce(0) { $0 + max($1.quantity, 0) }
            let needed = max(0, entry.quantity - onTrip)
            let zone = entry.zone.defaultForLoading(on: kind)

            for _ in 0 ..< needed {
                context.insert(LoadedItem(item: item, quantity: 1, zone: zone, trip: trip))
                addedToTrip += 1
            }
        }

        save(context)
        return addedToTrip
    }

    func updateLibraryItem(_ item: LibraryItem, name: String, weightKg: Double, in context: ModelContext) {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.weightKg = weightKg
        save(context)
    }

    private func save(_ context: ModelContext) {
        _ = SyncDebugSaveHelper.save(context, source: "LoadViewModel.save")
    }
}
