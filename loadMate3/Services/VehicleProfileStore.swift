import Foundation
import SwiftData

enum VehicleProfileStore {
    static func sortedProfiles(_ profiles: [VehicleProfile]) -> [VehicleProfile] {
        profiles.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func activeProfile(
        profiles: [VehicleProfile],
        appState: AppState?
    ) -> VehicleProfile? {
        let ordered = sortedProfiles(profiles)
        guard !ordered.isEmpty else { return nil }
        if let id = appState?.activeProfileID,
           let match = ordered.first(where: { $0.id == id }) {
            return match
        }
        return ordered.first
    }

    static func setActive(_ profile: VehicleProfile, appState: AppState, in context: ModelContext) {
        appState.activeProfileID = profile.id
        save(context)
    }

    /// Ensures `appState.activeProfileID` points at a real profile; defaults to the caravan when unset or stale.
    @MainActor
    static func ensureValidActiveProfile(
        profiles: [VehicleProfile],
        appState: AppState,
        in context: ModelContext
    ) {
        let ordered = sortedProfiles(profiles)
        guard !ordered.isEmpty else { return }

        if let activeID = appState.activeProfileID,
           ordered.contains(where: { $0.id == activeID }) {
            return
        }

        let defaultProfile = ordered.first(where: { $0.kind == .caravan }) ?? ordered[0]
        setActive(defaultProfile, appState: appState, in: context)
    }

    @MainActor
    static func ensureInitialData(
        in context: ModelContext,
        profiles queried: [VehicleProfile],
        appState: AppState?
    ) -> (profiles: [VehicleProfile], appState: AppState) {
        let state = appState ?? AppStateStore.ensure(in: context)

        // @Query can lag behind inserts from another tab; read the store before seeding defaults.
        var profiles = queried.isEmpty ? fetchProfiles(in: context) : queried

        if profiles.isEmpty {
            profiles = fetchProfiles(in: context)
            if profiles.isEmpty {
                let caravan = VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 0)
                context.insert(caravan)
                _ = TripStore.ensureDefaultTrip(for: caravan, in: context)

                let motorhome = VehicleProfile(name: "My Motorhome", kind: .motorhome, sortOrder: 1)
                context.insert(motorhome)
                _ = TripStore.ensureDefaultTrip(for: motorhome, in: context)

                setActive(caravan, appState: state, in: context)
                return ([caravan, motorhome], state)
            }
        }

        ensureValidActiveProfile(profiles: profiles, appState: state, in: context)

        TripStore.ensureTripsMigrated(in: context, profiles: profiles)

        return (sortedProfiles(profiles), state)
    }

    @MainActor
    static func addProfile(
        name: String,
        kind: VehicleKind,
        profiles: [VehicleProfile],
        appState: AppState,
        in context: ModelContext
    ) -> VehicleProfile {
        let nextOrder = (profiles.map(\.sortOrder).max() ?? -1) + 1
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = VehicleProfile(
            name: trimmed.isEmpty ? kind.displayName : trimmed,
            kind: kind,
            sortOrder: nextOrder
        )
        context.insert(profile)
        _ = TripStore.ensureDefaultTrip(for: profile, in: context)
        setActive(profile, appState: appState, in: context)
        return profile
    }

    @MainActor
    static func deleteProfile(
        _ profile: VehicleProfile,
        profiles: [VehicleProfile],
        appState: AppState,
        in context: ModelContext
    ) {
        guard profiles.count > 1 else { return }
        let wasActive = appState.activeProfileID == profile.id
        context.delete(profile)
        if wasActive {
            let remaining = profiles.filter { $0.id != profile.id }
            if let next = sortedProfiles(remaining).first {
                setActive(next, appState: appState, in: context)
            } else {
                appState.activeProfileID = nil
            }
        }
        save(context)
    }

    static func loadedItems(for profile: VehicleProfile?, from all: [LoadedItem]) -> [LoadedItem] {
        TripStore.loadedItems(for: TripStore.activeTrip(for: profile), from: all)
    }

    /// `@Query` can lag behind the store; read persisted rows when the query array is still empty.
    static func resolvedProfiles(queried: [VehicleProfile], in context: ModelContext) -> [VehicleProfile] {
        sortedProfiles(queried.isEmpty ? fetchProfiles(in: context) : queried)
    }

    /// Ensures vehicles exist, repairs the active selection, and returns data safe for Load/Summary tabs.
    @MainActor
    static func bootstrapForUse(
        in context: ModelContext,
        profiles queried: [VehicleProfile],
        appStates: [AppState]
    ) -> (profiles: [VehicleProfile], appState: AppState) {
        let state = AppStateStore.ensure(in: context, queried: appStates)
        let boot = ensureInitialData(in: context, profiles: queried, appState: state)
        ensureValidActiveProfile(profiles: boot.profiles, appState: state, in: context)
        return (boot.profiles, state)
    }

    private static func fetchProfiles(in context: ModelContext) -> [VehicleProfile] {
        (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
    }

    private static func save(_ context: ModelContext) {
        context.saveChanges("Saving your vehicle")
    }
}
