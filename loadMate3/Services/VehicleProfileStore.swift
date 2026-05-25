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

    @MainActor
    static func ensureInitialData(
        in context: ModelContext,
        profiles: [VehicleProfile],
        appState: AppState?
    ) -> (profiles: [VehicleProfile], appState: AppState) {
        let state: AppState
        if let appState {
            state = appState
        } else {
            let newState = AppState()
            context.insert(newState)
            state = newState
        }

        if profiles.isEmpty {
            let caravan = VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 0)
            context.insert(caravan)
            setActive(caravan, appState: state, in: context)
            return ([caravan], state)
        }

        if state.activeProfileID == nil, let first = sortedProfiles(profiles).first {
            setActive(first, appState: state, in: context)
        }

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
        guard let profile else { return [] }
        return all.filter { $0.profile?.id == profile.id }
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
