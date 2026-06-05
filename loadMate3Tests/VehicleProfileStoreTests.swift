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
}
