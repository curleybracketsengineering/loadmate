import Foundation
import SwiftData

enum LoadZone: String, Codable, CaseIterable, Identifiable {
    case frontLocker
    case front
    case middle
    case rear
    case bikeRack
    case unassigned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frontLocker: return "Front Locker"
        case .front: return "Front"
        case .middle: return "Middle (Axle)"
        case .rear: return "Rear"
        case .bikeRack: return "Bike Rack"
        case .unassigned: return "Unassigned"
        }
    }
}

@Model
final class SetupConfig {
    var baseWeightKg: Double
    var mtplmKg: Double
    var carMaxTowBallKg: Double

    var factorFrontLocker: Double
    var factorFront: Double
    var factorMiddle: Double
    var factorRear: Double
    var factorBikeRack: Double

    init(
        baseWeightKg: Double = 0,
        mtplmKg: Double = 0,
        carMaxTowBallKg: Double = 0,
        factorFrontLocker: Double = 0.25,
        factorFront: Double = 0.15,
        factorMiddle: Double = 0.0,
        factorRear: Double = -0.20,
        factorBikeRack: Double = -0.35
    ) {
        self.baseWeightKg = baseWeightKg
        self.mtplmKg = mtplmKg
        self.carMaxTowBallKg = carMaxTowBallKg
        self.factorFrontLocker = factorFrontLocker
        self.factorFront = factorFront
        self.factorMiddle = factorMiddle
        self.factorRear = factorRear
        self.factorBikeRack = factorBikeRack
    }
}

@Model
final class LibraryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var weightKg: Double
    var defaultZoneRaw: String?

    init(id: UUID = UUID(), name: String, weightKg: Double, defaultZoneRaw: String? = nil) {
        self.id = id
        self.name = name
        self.weightKg = weightKg
        self.defaultZoneRaw = defaultZoneRaw
    }

    var defaultZone: LoadZone? {
        get { defaultZoneRaw.flatMap(LoadZone.init(rawValue:)) }
        set { defaultZoneRaw = newValue?.rawValue }
    }
}

@Model
final class LoadedItem {
    @Attribute(.unique) var id: UUID
    var quantity: Int
    var zoneRaw: String
    var item: LibraryItem?

    init(id: UUID = UUID(), item: LibraryItem, quantity: Int = 1, zone: LoadZone = .unassigned) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.zoneRaw = zone.rawValue
    }

    var zone: LoadZone {
        get { LoadZone(rawValue: zoneRaw) ?? .unassigned }
        set { zoneRaw = newValue.rawValue }
    }
}

@Model
final class AppState {
    var disclaimerAccepted: Bool
    var acceptedAt: Date?

    init(disclaimerAccepted: Bool = false, acceptedAt: Date? = nil) {
        self.disclaimerAccepted = disclaimerAccepted
        self.acceptedAt = acceptedAt
    }
}
