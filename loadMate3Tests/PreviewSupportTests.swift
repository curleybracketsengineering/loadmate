import SwiftData
import Testing
@testable import loadMate3

@MainActor
@Suite("Preview support")
struct PreviewSupportTests {
    @Test("Preview seed matches production bootstrap with demo load items")
    func seedIfEmpty() throws {
        let context = try TestSupport.makeContext()
        try PreviewSupport.seedIfEmpty(in: context)

        var appStateDescriptor = FetchDescriptor<AppState>()
        appStateDescriptor.fetchLimit = 1
        let appState = try #require(try context.fetch(appStateDescriptor).first)
        #expect(appState.disclaimerAccepted)

        let profiles = try context.fetch(FetchDescriptor<VehicleProfile>())
        #expect(profiles.count == 2)

        let caravan = try #require(profiles.first { $0.kind == .caravan })
        let motorhome = try #require(profiles.first { $0.kind == .motorhome })
        #expect(caravan.name == "My Caravan")
        #expect(motorhome.name == "My Motorhome")
        #expect(caravan.mtplmKg == 0)
        #expect(motorhome.mtplmKg == 0)
        #expect(appState.activeProfileID == caravan.id)

        let loadedItems = try context.fetch(FetchDescriptor<LoadedItem>())
        #expect(!loadedItems.isEmpty)
    }
}
