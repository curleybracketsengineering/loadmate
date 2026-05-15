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
    /// Manufacturer MIRO — used when no weighbridge reading is entered.
    var baseWeightKg: Double
    /// Measured caravan weight before trip items are loaded; preferred over MIRO when set.
    var weighbridgeWeightKg: Double
    var mtplmKg: Double
    /// Maximum nose weight stamped on the caravan hitch (kg).
    var caravanMaxNoseKg: Double
    var carMaxTowBallKg: Double
    /// Baseline nose weight as % of total laden weight (default 6).
    var noseWeightBasePercent: Double

    var factorFrontLocker: Double
    var factorFront: Double
    var factorMiddle: Double
    var factorRear: Double
    var factorBikeRack: Double

    init(
        baseWeightKg: Double = 0,
        weighbridgeWeightKg: Double = 0,
        mtplmKg: Double = 0,
        caravanMaxNoseKg: Double = 0,
        carMaxTowBallKg: Double = 0,
        noseWeightBasePercent: Double = 6.0,
        factorFrontLocker: Double = 0.25,
        factorFront: Double = 0.15,
        factorMiddle: Double = 0.0,
        factorRear: Double = -0.20,
        factorBikeRack: Double = -0.35
    ) {
        self.baseWeightKg = baseWeightKg
        self.weighbridgeWeightKg = weighbridgeWeightKg
        self.mtplmKg = mtplmKg
        self.caravanMaxNoseKg = caravanMaxNoseKg
        self.carMaxTowBallKg = carMaxTowBallKg
        self.noseWeightBasePercent = noseWeightBasePercent
        self.factorFrontLocker = factorFrontLocker
        self.factorFront = factorFront
        self.factorMiddle = factorMiddle
        self.factorRear = factorRear
        self.factorBikeRack = factorBikeRack
    }
}

extension SetupConfig {
    /// Stricter of car tow ball and caravan nose limits when either is set.
    var effectiveMaxTowBallKg: Double {
        let limits = [carMaxTowBallKg, caravanMaxNoseKg].filter { $0 > 0 }
        return limits.min() ?? 0
    }

    /// Base weight for laden total: weighbridge when measured, otherwise MIRO.
    var calculationBaseWeightKg: Double {
        weighbridgeWeightKg > 0 ? weighbridgeWeightKg : baseWeightKg
    }

    /// True once a base weight (weighbridge or MIRO), MTPLM, and car tow-ball limit are set.
    var isConfiguredForWeightCalculations: Bool {
        calculationBaseWeightKg > 0 && mtplmKg > 0 && carMaxTowBallKg > 0
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
    /// When each unit was added (used for ordering and unload order).
    var loadedAt: Date = Date()
    var item: LibraryItem?

    init(id: UUID = UUID(), item: LibraryItem, quantity: Int = 1, zone: LoadZone = .unassigned, loadedAt: Date = Date()) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.zoneRaw = zone.rawValue
        self.loadedAt = loadedAt
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

@Model
final class ChecklistSection {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortOrder: Int

    /// Legacy flat items from older app versions (section → item). Prefer `groups` + `ChecklistItem.group`.
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
