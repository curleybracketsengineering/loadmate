import Foundation
@testable import loadMate3

enum TestFixtures {
    static func caravanProfile(
        name: String = "Test Caravan",
        baseWeight: Double = 1200,
        weighbridge: Double = 0,
        mtplm: Double = 1500,
        towBall: Double = 100,
        maxNose: Double = 0
    ) -> VehicleProfile {
        let profile = VehicleProfile(name: name, kind: .caravan)
        profile.baseWeightKg = baseWeight
        profile.weighbridgeWeightKg = weighbridge
        profile.mtplmKg = mtplm
        profile.carMaxTowBallKg = towBall
        profile.caravanMaxNoseKg = maxNose
        return profile
    }

    static func motorhomeProfile(
        name: String = "Test Motorhome",
        gross: Double = 3000,
        frontAxle: Double = 1350,
        rearAxle: Double = 1650,
        mam: Double = 3500,
        maxFront: Double = 1850,
        maxRear: Double = 2000,
        maxGarage: Double = 150,
        usesTowBar: Bool = false,
        maxTowBar: Double = 0
    ) -> VehicleProfile {
        let profile = VehicleProfile(name: name, kind: .motorhome)
        profile.weighbridgeWeightKg = gross
        profile.weighbridgeFrontAxleKg = frontAxle
        profile.weighbridgeRearAxleKg = rearAxle
        profile.mtplmKg = mam
        profile.maxFrontAxleKg = maxFront
        profile.maxRearAxleKg = maxRear
        profile.maxGarageKg = maxGarage
        profile.usesManualTowBarLoad = usesTowBar
        profile.maxTowBarKg = maxTowBar
        return profile
    }

    static func libraryItem(name: String, weightKg: Double) -> LibraryItem {
        LibraryItem(name: name, weightKg: weightKg)
    }

    static func loadedItem(
        item: LibraryItem,
        quantity: Int = 1,
        zone: LoadZone,
        trip: Trip? = nil
    ) -> LoadedItem {
        LoadedItem(item: item, quantity: quantity, zone: zone, trip: trip)
    }

    static func trip(name: String = "Weekend", profile: VehicleProfile? = nil, towBarLoad: Double = 0) -> Trip {
        Trip(name: name, manualTowBarLoadKg: towBarLoad, profile: profile)
    }
}
