import Foundation
import SwiftData
@testable import loadMate3

/// Shared helpers for building in-memory SwiftData fixtures so tests exercise the
/// real model relationships (and zone resolution) without touching disk.
enum TestSupport {
    static let schema = Schema([
        VehicleProfile.self,
        Trip.self,
        LibraryItem.self,
        LoadedItem.self,
        AppState.self,
        ChecklistSection.self,
        ChecklistGroup.self,
        ChecklistItem.self,
    ])

    @MainActor
    static func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    /// Builds a configured caravan profile and an active trip in a fresh context.
    @MainActor
    static func makeCaravan(
        baseWeightKg: Double = 1250,
        weighbridgeWeightKg: Double = 0,
        mtplmKg: Double = 1500,
        carMaxTowBallKg: Double = 100,
        caravanMaxNoseKg: Double = 0,
        noseWeightBasePercent: Double = 6.0,
        noseSafeZoneBasis: NoseSafeZoneBasis = .mtplm,
        hasBikeRack: Bool = false
    ) throws -> (context: ModelContext, profile: VehicleProfile, trip: Trip) {
        let context = try makeContext()
        let profile = VehicleProfile(name: "Test Caravan", kind: .caravan, sortOrder: 0)
        profile.baseWeightKg = baseWeightKg
        profile.weighbridgeWeightKg = weighbridgeWeightKg
        profile.mtplmKg = mtplmKg
        profile.carMaxTowBallKg = carMaxTowBallKg
        profile.caravanMaxNoseKg = caravanMaxNoseKg
        profile.noseWeightBasePercent = noseWeightBasePercent
        profile.noseSafeZoneBasis = noseSafeZoneBasis
        profile.hasBikeRack = hasBikeRack
        context.insert(profile)

        let trip = Trip(name: "Test Trip", sortOrder: 0, profile: profile)
        context.insert(trip)
        profile.activeTripID = trip.id

        return (context, profile, trip)
    }

    /// Builds a configured motorhome profile and an active trip in a fresh context.
    @MainActor
    static func makeMotorhome(
        baseWeightKg: Double = 3000,
        weighbridgeWeightKg: Double = 0,
        weighbridgeFrontAxleKg: Double = 0,
        weighbridgeRearAxleKg: Double = 0,
        axleSplitFrontPercent: Double = 45,
        mamKg: Double = 3500,
        maxFrontAxleKg: Double = 1600,
        maxRearAxleKg: Double = 2000,
        maxGarageKg: Double = 0,
        garageLimitIncludesBikeRack: Bool = false,
        usesManualTowBarLoad: Bool = false,
        maxTowBarKg: Double = 0,
        hasBikeRack: Bool = false
    ) throws -> (context: ModelContext, profile: VehicleProfile, trip: Trip) {
        let context = try makeContext()
        let profile = VehicleProfile(name: "Test Motorhome", kind: .motorhome, sortOrder: 0)
        profile.baseWeightKg = baseWeightKg
        profile.weighbridgeWeightKg = weighbridgeWeightKg
        profile.weighbridgeFrontAxleKg = weighbridgeFrontAxleKg
        profile.weighbridgeRearAxleKg = weighbridgeRearAxleKg
        profile.axleSplitFrontPercent = axleSplitFrontPercent
        profile.mtplmKg = mamKg
        profile.maxFrontAxleKg = maxFrontAxleKg
        profile.maxRearAxleKg = maxRearAxleKg
        profile.maxGarageKg = maxGarageKg
        profile.garageLimitIncludesBikeRack = garageLimitIncludesBikeRack
        profile.usesManualTowBarLoad = usesManualTowBarLoad
        profile.maxTowBarKg = maxTowBarKg
        profile.hasBikeRack = hasBikeRack
        context.insert(profile)

        let trip = Trip(name: "Test Trip", sortOrder: 0, profile: profile)
        context.insert(trip)
        profile.activeTripID = trip.id

        return (context, profile, trip)
    }

    /// Inserts a loaded item (with backing library item) onto a trip in a given zone.
    @MainActor
    @discardableResult
    static func addLoadedItem(
        weightKg: Double,
        quantity: Int = 1,
        zone: LoadZone,
        trip: Trip,
        in context: ModelContext,
        name: String = "Item"
    ) -> LoadedItem {
        let libraryItem = LibraryItem(name: name, weightKg: weightKg)
        context.insert(libraryItem)
        let loaded = LoadedItem(item: libraryItem, quantity: quantity, zone: zone, trip: trip)
        context.insert(loaded)
        return loaded
    }
}
