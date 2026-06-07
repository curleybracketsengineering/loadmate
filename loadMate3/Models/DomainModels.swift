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
        case .caravan: return "tow.hitch.fill"
        case .motorhome: return "bus.fill"
        }
    }
}

/// What mass to use when calculating the 5%–7% nose weight safe band.
enum NoseSafeZoneBasis: String, Codable, CaseIterable, Identifiable {
    case mtplm
    case ladenWeight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mtplm: return "MTPLM"
        case .ladenWeight: return "Laden weight"
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
        case .driver: return "Cab"
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
    /// Stored basis for 5%–7% safe zone; default MTPLM for existing profiles.
    var noseSafeZoneBasisRaw: String = NoseSafeZoneBasis.mtplm.rawValue

    var factorFrontLocker: Double
    var factorFront: Double
    var factorMiddle: Double
    var factorRear: Double
    var factorBikeRack: Double
    /// Rear bike rack fitted — controls placement art and whether the bike rack zone is offered.
    var hasBikeRack: Bool

    // MARK: Motorhome axle weighbridge & limits

    var weighbridgeFrontAxleKg: Double
    var weighbridgeRearAxleKg: Double
    /// Used when axle weights are not entered: front axle share of base mass (%).
    var axleSplitFrontPercent: Double
    var maxFrontAxleKg: Double
    var maxRearAxleKg: Double
    /// Max load for the rear garage / overhang box (0 = not set — no separate limit).
    var maxGarageKg: Double
    /// When true, trip items in the bike rack zone count toward `maxGarageKg` (manufacturer combined rear limit).
    var garageLimitIncludesBikeRack: Bool
    /// Motorhome: user tows with a tow bar — enter load per trip on the Load tab.
    var usesManualTowBarLoad: Bool
    /// Maximum tow bar (nose) load the motorhome tow bar can take (0 = not set).
    var maxTowBarKg: Double

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
    var mhFactorBikeRackFront: Double
    var mhFactorBikeRackRear: Double

    /// Last-selected load setup for this vehicle (beach, Europe, etc.).
    var activeTripID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \Trip.profile)
    var trips: [Trip] = []

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
        self.noseSafeZoneBasisRaw = NoseSafeZoneBasis.mtplm.rawValue
        self.factorFrontLocker = 0.25
        self.factorFront = 0.15
        self.factorMiddle = 0.0
        self.factorRear = -0.20
        self.factorBikeRack = -0.35
        self.hasBikeRack = false
        self.weighbridgeFrontAxleKg = 0
        self.weighbridgeRearAxleKg = 0
        self.axleSplitFrontPercent = 45
        self.maxFrontAxleKg = 0
        self.maxRearAxleKg = 0
        self.maxGarageKg = 0
        self.garageLimitIncludesBikeRack = false
        self.usesManualTowBarLoad = false
        self.maxTowBarKg = 0
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
        self.mhFactorBikeRackFront = -0.08
        self.mhFactorBikeRackRear = 1.08
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
    /// Cab ahead of the front axle; Middle between axles; Rear above the rear axle; Garage and bike rack behind the rear axle.
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
        profile.mhFactorBikeRackFront = -0.08
        profile.mhFactorBikeRackRear = 1.08
    }
}

extension VehicleProfile {
    /// iPad cutaway asset for the active vehicle configuration.
    var padCutawayAssetName: String {
        switch kind {
        case .caravan:
            return hasBikeRack ? "caravanAndBike" : "Caravan"
        case .motorhome:
            switch (usesManualTowBarLoad, hasBikeRack) {
            case (true, true): return "MotorhomeTowBike"
            case (true, false): return "MotorhomeTow"
            case (false, true): return "MotorhomeBike"
            case (false, false): return "Motorhome"
            }
        }
    }

    /// Zone chips left-to-right above the iPad cutaway (front/cab on the left, rear on the right).
    var padZoneDisplayOrder: [LoadZone] {
        switch kind {
        case .caravan:
            let zones: [LoadZone] = [.frontLocker, .front, .middle, .rear, .bikeRack]
            return hasBikeRack ? zones : zones.filter { $0 != .bikeRack }
        case .motorhome:
            let zones: [LoadZone] = [.driver, .central, .back, .garage, .bikeRack]
            return hasBikeRack ? zones : zones.filter { $0 != .bikeRack }
        }
    }

    /// Wording for garage limit UI when monitoring rear storage.
    var garageLimitSourcesLabel: String {
        garageLimitIncludesBikeRack ? "Garage and bike rack" : "Garage only"
    }

    var effectiveMaxTowBallKg: Double {
        let limits = [carMaxTowBallKg, caravanMaxNoseKg].filter { $0 > 0 }
        return limits.min() ?? 0
    }

    var noseSafeZoneBasis: NoseSafeZoneBasis {
        get { NoseSafeZoneBasis(rawValue: noseSafeZoneBasisRaw) ?? .mtplm }
        set { noseSafeZoneBasisRaw = newValue.rawValue }
    }

    /// Mass used for 5% / 7% nose safe-zone bounds (car and hitch caps still apply separately).
    func noseSafeZoneReferenceWeightKg(totalLadenWeightKg: Double) -> Double {
        switch noseSafeZoneBasis {
        case .mtplm:
            return mtplmKg > 0 ? mtplmKg : totalLadenWeightKg
        case .ladenWeight:
            return totalLadenWeightKg
        }
    }

    var calculationBaseWeightKg: Double {
        if kind == .motorhome {
            let axleSum = weighbridgeFrontAxleKg + weighbridgeRearAxleKg
            if MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: self) {
                return axleSum
            }
            if weighbridgeWeightKg > 0 { return weighbridgeWeightKg }
            if axleSum > 0 { return axleSum }
        }
        return weighbridgeWeightKg > 0 ? weighbridgeWeightKg : baseWeightKg
    }

    var baselineFrontAxleKg: Double {
        if kind == .motorhome, motorhomeHasConflictingWeighbridgeEntries {
            let pct = axleSplitFrontPercent > 0 ? axleSplitFrontPercent : 45
            return calculationBaseWeightKg * (pct / 100.0)
        }
        if weighbridgeFrontAxleKg > 0 { return weighbridgeFrontAxleKg }
        let pct = axleSplitFrontPercent > 0 ? axleSplitFrontPercent : 45
        return calculationBaseWeightKg * (pct / 100.0)
    }

    var baselineRearAxleKg: Double {
        if kind == .motorhome, motorhomeHasConflictingWeighbridgeEntries {
            return calculationBaseWeightKg - baselineFrontAxleKg
        }
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

/// Subjective towing/handling rating recorded per trip after a real tow or test drive.
enum TowingExperience: String, Codable, CaseIterable, Identifiable {
    case notSet
    case excellent
    case good
    case fair
    case poor
    case unstable
    case notTowedYet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notSet: return "Not set"
        case .excellent: return "Great — stable"
        case .good: return "OK"
        case .fair: return "A bit twitchy"
        case .poor: return "Poor"
        case .unstable: return "Sway / instability"
        case .notTowedYet: return "Not towed yet"
        }
    }

    /// Options shown in the trip-notes picker (excludes the unset sentinel).
    static var pickerCases: [TowingExperience] {
        allCases.filter { $0 != .notSet }
    }
}

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    /// Manually entered tow bar (nose) load for this trip (kg).
    var manualTowBarLoadKg: Double
    /// Caravan: nose weight measured on a gauge for this trip (kg). 0 = not set.
    var measuredNoseWeightKg: Double = 0
    /// Caravan: subjective towing experience for this trip setup.
    var towingExperienceRaw: String = TowingExperience.notSet.rawValue
    /// Free-form notes for this trip loading (caravan short notes; motorhome general notes).
    var tripNotes: String = ""

    var profile: VehicleProfile?

    @Relationship(deleteRule: .cascade, inverse: \LoadedItem.trip)
    var loadedItems: [LoadedItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        manualTowBarLoadKg: Double = 0,
        measuredNoseWeightKg: Double = 0,
        towingExperienceRaw: String = TowingExperience.notSet.rawValue,
        tripNotes: String = "",
        profile: VehicleProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.manualTowBarLoadKg = manualTowBarLoadKg
        self.measuredNoseWeightKg = measuredNoseWeightKg
        self.towingExperienceRaw = towingExperienceRaw
        self.tripNotes = tripNotes
        self.profile = profile
    }

    var towingExperience: TowingExperience {
        get { TowingExperience(rawValue: towingExperienceRaw) ?? .notSet }
        set { towingExperienceRaw = newValue.rawValue }
    }

    func hasLoadingNotes(for kind: VehicleKind) -> Bool {
        switch kind {
        case .caravan:
            return measuredNoseWeightKg > 0
                || towingExperience != .notSet
                || !trimmedTripNotes.isEmpty
        case .motorhome:
            return !trimmedTripNotes.isEmpty
        }
    }

    var trimmedTripNotes: String {
        tripNotes.trimmingCharacters(in: .whitespacesAndNewlines)
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
    var trip: Trip?
    /// Legacy link; new items use `trip` only. Kept for SwiftData migration from older stores.
    var profile: VehicleProfile?

    init(
        id: UUID = UUID(),
        item: LibraryItem,
        quantity: Int = 1,
        zone: LoadZone = .unassigned,
        loadedAt: Date = Date(),
        trip: Trip? = nil,
        profile: VehicleProfile? = nil
    ) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.zoneRaw = zone.rawValue
        self.loadedAt = loadedAt
        self.trip = trip
        self.profile = profile ?? trip?.profile
    }

    var zone: LoadZone {
        get {
            let kind = (trip?.profile ?? profile)?.kind ?? .caravan
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
