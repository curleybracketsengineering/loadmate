import Foundation
import Combine
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    func bootstrap(
        in context: ModelContext,
        profiles: [VehicleProfile],
        appState: AppState?
    ) -> (profiles: [VehicleProfile], appState: AppState) {
        let state = AppStateStore.ensure(in: context, existing: appState)
        return VehicleProfileStore.ensureInitialData(in: context, profiles: profiles, appState: state)
    }

    func setActiveProfile(_ profile: VehicleProfile, appState: AppState, in context: ModelContext) {
        VehicleProfileStore.setActive(profile, appState: appState, in: context)
    }

    func addProfile(
        name: String,
        kind: VehicleKind,
        profiles: [VehicleProfile],
        appState: AppState,
        in context: ModelContext
    ) -> VehicleProfile {
        VehicleProfileStore.addProfile(
            name: name,
            kind: kind,
            profiles: profiles,
            appState: appState,
            in: context
        )
    }

    func deleteProfile(
        _ profile: VehicleProfile,
        profiles: [VehicleProfile],
        appState: AppState,
        in context: ModelContext
    ) {
        VehicleProfileStore.deleteProfile(profile, profiles: profiles, appState: appState, in: context)
    }

    func resetCaravanFactors(profile: VehicleProfile, in context: ModelContext) {
        VehicleProfile.applyCaravanFactorDefaults(to: profile)
        save(context)
    }

    func resetMotorhomeFactors(profile: VehicleProfile, in context: ModelContext) {
        VehicleProfile.applyMotorhomeFactorDefaults(to: profile)
        save(context)
    }

    func save(_ context: ModelContext) {
        context.saveChanges("Saving your settings")
    }
}
