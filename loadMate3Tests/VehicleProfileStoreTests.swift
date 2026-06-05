import SwiftData
import Testing
@testable import loadMate3

@MainActor
@Suite("Vehicle profile store")
struct VehicleProfileStoreTests {
    @Test("Initial bootstrap creates empty caravan and motorhome with caravan active")
    func ensureInitialData() throws {
        let context = try TestSupport.makeContext()
        let boot = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: nil)

        #expect(boot.profiles.count == 2)
        let caravan = try #require(boot.profiles.first { $0.kind == .caravan })
        let motorhome = try #require(boot.profiles.first { $0.kind == .motorhome })
        #expect(caravan.name == "My Caravan")
        #expect(motorhome.name == "My Motorhome")
        #expect(caravan.mtplmKg == 0)
        #expect(motorhome.maxFrontAxleKg == 0)
        #expect(boot.appState.activeProfileID == caravan.id)
        #expect(TripStore.activeTrip(for: caravan) != nil)
        #expect(TripStore.activeTrip(for: motorhome) != nil)
    }

    @Test("Empty query reuses profiles already stored in the context")
    func ensureInitialDataReusesStoredProfiles() throws {
        let context = try TestSupport.makeContext()
        let firstBoot = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: nil)
        #expect(firstBoot.profiles.count == 2)

        let secondBoot = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: firstBoot.appState)

        #expect(secondBoot.profiles.count == 2)
        #expect(try context.fetch(FetchDescriptor<VehicleProfile>()).count == 2)
    }

    @Test("Stale active profile ID is repaired to the default caravan")
    func ensureValidActiveProfileDefaultsToCaravan() throws {
        let context = try TestSupport.makeContext()
        let boot = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: nil)
        let state = boot.appState
        state.activeProfileID = UUID()

        VehicleProfileStore.ensureValidActiveProfile(
            profiles: boot.profiles,
            appState: state,
            in: context
        )

        let caravan = try #require(boot.profiles.first { $0.kind == .caravan })
        #expect(state.activeProfileID == caravan.id)
    }

    @Test("Concurrent empty bootstrap does not create duplicate default vehicles")
    func ensureInitialDataAvoidsDuplicateSeeding() async throws {
        let context = try TestSupport.makeContext()

        async let first = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: nil)
        async let second = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: nil)

        _ = await (first, second)

        let stored = try context.fetch(FetchDescriptor<VehicleProfile>())
        #expect(stored.count == 2)
    }
}
