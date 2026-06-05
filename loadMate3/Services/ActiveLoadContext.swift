import Foundation
import SwiftData

/// Resolves the active vehicle, its active trip, and that trip's loaded items from the
/// `@Query`-backed arrays a view holds.
///
/// Several screens previously repeated the same three computed properties (`activeProfile`,
/// `activeTrip`, `profileLoadedItems`) verbatim. This value type centralizes that logic so the
/// resolution rules live in one place.
struct ActiveLoadContext {
    let profile: VehicleProfile?
    let trip: Trip?
    let loadedItems: [LoadedItem]

    @MainActor
    init(
        profiles: [VehicleProfile],
        modelContext: ModelContext,
        appStates: [AppState],
        allLoadedItems: [LoadedItem]
    ) {
        let appState = AppStateStore.ensure(in: modelContext, queried: appStates)
        let orderedProfiles = VehicleProfileStore.resolvedProfiles(queried: profiles, in: modelContext)
        let resolvedProfile = VehicleProfileStore.activeProfile(profiles: orderedProfiles, appState: appState)
        let resolvedTrip = TripStore.activeTrip(for: resolvedProfile)
        self.profile = resolvedProfile
        self.trip = resolvedTrip
        self.loadedItems = TripStore.loadedItems(for: resolvedTrip, from: allLoadedItems)
    }
}
