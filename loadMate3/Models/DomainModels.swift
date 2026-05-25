import Foundation
import SwiftData

enum VehicleKind: String, Codable, CaseIterable, Identifiable {
    case caravan
    case motorhome

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .caravan: return "Caravan"
        case .motorhome: return "Motorhome"
        }
    }

    var systemImage: String {
        switch self {
        case .caravan: return "car.rear.and.trailer.road.lane"
        case .motorhome: return "bus.fill"
        }
    }
}

enum LoadZone: String, Codable, CaseIterable, Identifiable {
    // Caravan
    case frontLocker
    case middle
    case rear
    case bikeRack
    // Shared
    case front
    // Motorhome
    case driver
    case central
    case back
    case garage
    case unassigned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frontLocker: return "Front Locker"
        case .front: return "Front"
        case .middle: return "Middle (Axle)"
        case .rear: return "Rear"
        case .bikeRack: return "Bike Rack"
        case .driver: return "Driver"
        case .central: return "Central"
        case .back: return "Back"
        case .garage: return "Garage"
        case .unassigned: return "Unassigned"
        }
    }
}

@Model
final class VehicleProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var sortOrder: Int

    /// Manufacturer MIRO / MRO — used when no weighbridge reading is entered.
    var baseWeightKg: Double
    /// Measured laden mass before trip items (caravan total or motorhome gross).
    var weighbridgeWeightKg: Double

    /// MTPLM (caravan) or MAM (motorhome).
    var mtplmKg: Double

    // MARK: Caravan

    var caravanMaxNoseKg: Double
    var carMaxTowBallKg: Double
    var noseWeightBasePercent: Double

    var factorFrontLocker: Double
    var factorFront: Double
    var factorMiddle: Double
    var factorRear: Double
    var factorBikeRack: Double

    // MARK: Motorhome axle weighbridge & limits

    var weighbridgeFrontAxleKg: Double
    var weighbridgeRearAxleKg: Double
    /// Used when axle weights are not entered: front axle share of base mass (%).
    var axleSplitFrontPercent: Double
    var maxFrontAxleKg: Double
    var maxRearAxleKg: Double
    /// Max load for the rear garage / overhang box (0 = not set — no separate limit).
    var maxGarageKg: Double

    /// Motorhome: kg added to each axle estimate per kg of item in that zone.
    var mhFactorDriverFront: Double
    var mhFactorDriverRear: Double
    var mhFactorFrontFront: Double
    var mhFactorFrontRear: Double
    var mhFactorCentralFront: Double
    var mhFactorCentralRear: Double
    var mhFactorBackFront: Double
    var mhFactorBackRear: Double
    var mhFactorGarageFront: Double
    var mhFactorGarageRear: Double

    @Relationship(deleteRule: .cascade, inverse: \LoadedItem.profile)
    var loadedItems: [LoadedItem] = []

    init(
        id: UUID = UUID(),
        name: String = "My vehicle",
        kind: VehicleKind = .caravan,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.baseWeightKg = 0
        self.weighbridgeWeightKg = 0
        self.mtplmKg = 0
        self.caravanMaxNoseKg = 0
        self.carMaxTowBallKg = 0
        self.noseWeightBasePercent = 6.0
        self.factorFrontLocker = 0.25
        self.factorFront = 0.15
        self.factorMiddle = 0.0
        self.factorRear = -0.20
        self.factorBikeRack = -0.35
        self.weighbridgeFrontAxleKg = 0
        self.weighbridgeRearAxleKg = 0
        self.axleSplitFrontPercent = 45
        self.maxFrontAxleKg = 0
        self.maxRearAxleKg = 0
        self.maxGarageKg = 0
        self.mhFactorDriverFront = 0.75
        self.mhFactorDriverRear = 0.15
        self.mhFactorFrontFront = 0.95
        self.mhFactorFrontRear = 0.05
        self.mhFactorCentralFront = 0.50
        self.mhFactorCentralRear = 0.50
        self.mhFactorBackFront = 0.05
        self.mhFactorBackRear = 0.95
        self.mhFactorGarageFront = 0.02
        self.mhFactorGarageRear = 0.98
    }

    var kind: VehicleKind {
        get { VehicleKind(rawValue: kindRaw) ?? .caravan }
        set { kindRaw = newValue.rawValue }
    }

    static func applyCaravanFactorDefaults(to profile: VehicleProfile) {
        profile.factorFrontLocker = 0.25
        profile.factorFront = 0.15
        profile.factorMiddle = 0.0
        profile.factorRear = -0.20
        profile.factorBikeRack = -0.35
    }

    /// Per-kg factors: how much each kg in a zone adds to front vs rear axle estimates.
    /// Front zone sits above the front axle; Back above the rear axle; Garage behind the rear axle.
    static func applyMotorhomeFactorDefaults(to profile: VehicleProfile) {
        profile.mhFactorDriverFront = 0.75
        profile.mhFactorDriverRear = 0.15
        profile.mhFactorFrontFront = 0.95
        profile.mhFactorFrontRear = 0.05
        profile.mhFactorCentralFront = 0.50
        profile.mhFactorCentralRear = 0.50
        profile.mhFactorBackFront = 0.05
        profile.mhFactorBackRear = 0.95
        profile.mhFactorGarageFront = 0.02
        profile.mhFactorGarageRear = 0.98
    }
}

extension VehicleProfile {
    var effectiveMaxTowBallKg: Double {
        let limits = [carMaxTowBallKg, caravanMaxNoseKg].filter { $0 > 0 }
        return limits.min() ?? 0
    }

    var calculationBaseWeightKg: Double {
        if kind == .motorhome {
            let axleSum = weighbridgeFrontAxleKg + weighbridgeRearAxleKg
            if axleSum > 0 { return axleSum }
        }
        return weighbridgeWeightKg > 0 ? weighbridgeWeightKg : baseWeightKg
    }

    var baselineFrontAxleKg: Double {
        if weighbridgeFrontAxleKg > 0 { return weighbridgeFrontAxleKg }
        let pct = axleSplitFrontPercent > 0 ? axleSplitFrontPercent : 45
        return calculationBaseWeightKg * (pct / 100.0)
    }

    var baselineRearAxleKg: Double {
        if weighbridgeRearAxleKg > 0 { return weighbridgeRearAxleKg }
        return calculationBaseWeightKg - baselineFrontAxleKg
    }

    var isConfiguredForWeightCalculations: Bool {
        switch kind {
        case .caravan:
            return calculationBaseWeightKg > 0 && mtplmKg > 0 && carMaxTowBallKg > 0
        case .motorhome:
            return calculationBaseWeightKg > 0 && mtplmKg > 0 && maxFrontAxleKg > 0 && maxRearAxleKg > 0
        }
    }

    var grossMassLabel: String {
        kind == .motorhome ? "MAM" : "MTPLM"
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
    var loadedAt: Date = Date()
    var item: LibraryItem?
    var profile: VehicleProfile?

    init(
        id: UUID = UUID(),
        item: LibraryItem,
        quantity: Int = 1,
        zone: LoadZone = .unassigned,
        loadedAt: Date = Date(),
        profile: VehicleProfile? = nil
    ) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.zoneRaw = zone.rawValue
        self.loadedAt = loadedAt
        self.profile = profile
    }

    var zone: LoadZone {
        get {
            let kind = profile?.kind ?? .caravan
            return LoadZone.resolved(rawValue: zoneRaw, for: kind)
        }
        set { zoneRaw = newValue.rawValue }
    }
}

@Model
final class AppState {
    var disclaimerAccepted: Bool
    var acceptedAt: Date?
    var activeProfileID: UUID?

    init(disclaimerAccepted: Bool = false, acceptedAt: Date? = nil, activeProfileID: UUID? = nil) {
        self.disclaimerAccepted = disclaimerAccepted
        self.acceptedAt = acceptedAt
        self.activeProfileID = activeProfileID
    }
}

@Model
final class ChecklistSection {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.section)
    var items: [ChecklistItem] = []

    @Relationship(deleteRule: .cascade, inverse: \ChecklistGroup.section)
    var groups: [ChecklistGroup] = []

    init(id: UUID = UUID(), title: String, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
    }
}

@Model
final class ChecklistGroup {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortOrder: Int

    var section: ChecklistSection?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.group)
    var items: [ChecklistItem] = []

    init(id: UUID = UUID(), title: String, sortOrder: Int = 0, section: ChecklistSection? = nil) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.section = section
    }
}

@Model
final class ChecklistItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isChecked: Bool
    var sortOrder: Int

    var section: ChecklistSection?
    var group: ChecklistGroup?

    init(
        id: UUID = UUID(),
        title: String,
        isChecked: Bool = false,
        sortOrder: Int = 0,
        section: ChecklistSection? = nil,
        group: ChecklistGroup? = nil
    ) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
        self.sortOrder = sortOrder
        self.section = section
        self.group = group
    }
}
