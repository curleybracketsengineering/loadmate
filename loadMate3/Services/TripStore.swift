import Foundation
import SwiftData

enum TripStore {
    static let defaultTripName = "Default"

    static func sortedTrips(for profile: VehicleProfile?) -> [Trip] {
        guard let profile else { return [] }
        return profile.tripsList.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func activeTrip(for profile: VehicleProfile?) -> Trip? {
        guard let profile else { return nil }
        let ordered = sortedTrips(for: profile)
        guard !ordered.isEmpty else { return nil }
        if let id = profile.activeTripID,
           let match = ordered.first(where: { $0.id == id }) {
            return match
        }
        return ordered.first
    }

    static func setActive(_ trip: Trip, on profile: VehicleProfile, in context: ModelContext) {
        profile.activeTripID = trip.id
        save(context)
    }

    static func loadedItems(for trip: Trip?, from all: [LoadedItem]) -> [LoadedItem] {
        guard let trip else { return [] }
        return all.filter { $0.trip?.id == trip.id }
    }

    @MainActor
    static func ensureTripsMigrated(in context: ModelContext, profiles: [VehicleProfile]) {
        let allLoadedItems = (try? context.fetch(FetchDescriptor<LoadedItem>())) ?? []
        var didChange = false

        for profile in profiles {
            let defaultTrip: Trip
            if profile.tripsList.isEmpty {
                let trip = Trip(name: defaultTripName, sortOrder: 0, profile: profile)
                context.insert(trip)
                profile.activeTripID = trip.id
                defaultTrip = trip
                didChange = true
            } else {
                defaultTrip = sortedTrips(for: profile).first!
                if profile.activeTripID == nil {
                    profile.activeTripID = defaultTrip.id
                    didChange = true
                }
            }

            for loaded in allLoadedItems where loaded.trip == nil && loaded.profile?.id == profile.id {
                loaded.trip = defaultTrip
                loaded.profile = nil
                didChange = true
            }
        }

        if didChange {
            save(context)
        }
    }

    @MainActor
    static func addTrip(
        name: String,
        to profile: VehicleProfile,
        in context: ModelContext
    ) -> Trip {
        let nextOrder = (profile.tripsList.map(\.sortOrder).max() ?? -1) + 1
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = Trip(
            name: trimmed.isEmpty ? "New trip" : trimmed,
            sortOrder: nextOrder,
            profile: profile
        )
        context.insert(trip)
        setActive(trip, on: profile, in: context)
        return trip
    }

    @MainActor
    static func renameTrip(_ trip: Trip, name: String, in context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        trip.name = trimmed
        save(context)
    }

    @MainActor
    static func deleteTrip(
        _ trip: Trip,
        from profile: VehicleProfile,
        in context: ModelContext
    ) {
        let ordered = sortedTrips(for: profile)
        guard ordered.count > 1 else { return }
        let wasActive = profile.activeTripID == trip.id
        let nextTrip = ordered.first { $0.id != trip.id }
        context.delete(trip)
        if wasActive, let nextTrip {
            profile.activeTripID = nextTrip.id
        }
        save(context)
    }

    @MainActor
    static func ensureDefaultTrip(
        for profile: VehicleProfile,
        preferredID: UUID? = nil,
        in context: ModelContext
    ) -> Trip {
        if let existing = activeTrip(for: profile) {
            return existing
        }

        if let preferredID,
           let existing = profile.tripsList.first(where: { $0.id == preferredID }) {
            profile.activeTripID = existing.id
            save(context)
            return existing
        }

        let trip = Trip(
            id: preferredID ?? UUID(),
            name: defaultTripName,
            sortOrder: 0,
            profile: profile
        )
        context.insert(trip)
        setActive(trip, on: profile, in: context)
        return trip
    }

    private static func save(_ context: ModelContext) {
        _ = SyncDebugSaveHelper.save(context, source: "TripStore.save")
    }
}
