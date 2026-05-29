import UIKit

/// Chooses between phone and iPad presentation. iPhone UI stays on compact phone idiom only.
enum AppLayout {
    static var usePadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

extension VehicleKind {
    /// Asset catalog name for the iPad cutaway illustration.
    var padCutawayAssetName: String {
        switch self {
        case .caravan: return "Caravan"
        case .motorhome: return "Motorhome"
        }
    }

    /// Zone chips left-to-right above the cutaway (matches mockup artwork).
    var padZoneDisplayOrder: [LoadZone] {
        switch self {
        case .caravan:
            return [.bikeRack, .rear, .middle, .front, .frontLocker]
        case .motorhome:
            return [.bikeRack, .garage, .back, .central, .driver]
        }
    }
}

extension LoadZone {
    /// Short label on iPad zone chips (motorhome garage shown as “Boot” per mockup).
    func padChipTitle(for kind: VehicleKind) -> String {
        if kind == .motorhome, self == .garage { return "Boot" }
        if kind == .motorhome, self == .bikeRack { return "Bike" }
        return locationBadgeTitle(for: kind)
    }
}
