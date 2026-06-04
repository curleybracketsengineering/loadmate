import SwiftUI

extension LoadZone {
    // MARK: Caravan zones

    static let caravanPickerZones: [LoadZone] = [.frontLocker, .front, .middle, .rear, .bikeRack]

    // MARK: Motorhome zones

    static let motorhomePickerZones: [LoadZone] = [.driver, .central, .back, .garage, .bikeRack]

    static func pickerZones(for kind: VehicleKind, profile: VehicleProfile? = nil) -> [LoadZone] {
        var zones = kind == .motorhome ? motorhomePickerZones : caravanPickerZones
        if let profile, !profile.hasBikeRack {
            zones = zones.filter { $0 != .bikeRack }
        }
        return zones
    }

    /// Zone used for weight distribution math when the user has not assigned a location.
    func calculationZone(for kind: VehicleKind) -> LoadZone {
        guard self != .unassigned else {
            return kind == .motorhome ? .central : .middle
        }
        return LoadZone.resolved(rawValue: rawValue, for: kind)
    }

    static var motorhomeGarageZone: LoadZone { .garage }

    /// Maps legacy caravan zone raw values stored on motorhome loads to motorhome zones.
    static func resolved(rawValue: String, for kind: VehicleKind) -> LoadZone {
        guard let zone = LoadZone(rawValue: rawValue) else { return .unassigned }
        guard kind == .motorhome else { return zone }
        switch zone {
        case .frontLocker: return .driver
        case .front: return .central
        case .middle: return .central
        case .rear: return .back
        default: return zone
        }
    }

    /// Default zone when loading an item onto a profile (maps shared library defaults per kind).
    func defaultForLoading(on kind: VehicleKind) -> LoadZone {
        guard kind == .motorhome else { return self }
        switch self {
        case .frontLocker: return .driver
        case .front: return .central
        case .middle: return .central
        case .rear: return .back
        default: return self
        }
    }

    func locationBadgeTitle(for kind: VehicleKind) -> String {
        switch kind {
        case .caravan:
            switch self {
            case .frontLocker: return "Locker"
            case .front: return "Front"
            case .middle: return "Middle"
            case .rear: return "Rear"
            case .bikeRack: return "Bike"
            case .driver, .central, .back, .garage: return title
            case .unassigned: return "Unassigned"
            }
        case .motorhome:
            switch self {
            case .driver: return "Cab"
            case .central: return "Middle"
            case .back: return "Rear"
            case .garage: return "Garage"
            case .bikeRack: return "Bike Rack"
            case .unassigned: return "Unassigned"
            default: return LoadZone.resolved(rawValue: rawValue, for: .motorhome).locationBadgeTitle(for: .motorhome)
            }
        }
    }

    /// Short labels for the motorhome position map so every box is the same size.
    func mapBadgeTitle(for kind: VehicleKind) -> String {
        guard kind == .motorhome else { return locationBadgeTitle(for: kind) }
        switch self {
        case .driver: return "Cab"
        case .central: return "Mid."
        case .back: return "Rear"
        case .garage: return "Gar."
        case .bikeRack: return "Bike"
        case .unassigned: return "—"
        default: return LoadZone.resolved(rawValue: rawValue, for: .motorhome).mapBadgeTitle(for: .motorhome)
        }
    }

    func locationImpactHint(for kind: VehicleKind) -> String {
        switch kind {
        case .caravan:
            switch self {
            case .frontLocker: return "Increases nose weight most"
            case .front: return "Increases nose weight"
            case .middle: return "Neutral impact on nose weight"
            case .rear: return "Decreases nose weight"
            case .bikeRack: return "Decreases nose weight most"
            case .unassigned: return ""
            default: return ""
            }
        case .motorhome:
            switch self {
            case .driver: return "Ahead of front axle — mostly front"
            case .central: return "Between axles — shared"
            case .back: return "Above rear axle"
            case .garage: return "Behind rear axle — garage limit"
            case .bikeRack: return "Rear rack — strongly loads rear axle"
            case .unassigned: return ""
            default: return ""
            }
        }
    }

    /// Zone accent for chips and badges (caravan defaults when kind is omitted).
    var chipAccentColor: Color {
        chipAccentColor(for: .caravan)
    }

    func chipAccentColor(for kind: VehicleKind) -> Color {
        switch kind {
        case .motorhome:
            switch self {
            case .driver: return AppColors.orange
            case .central: return AppColors.blue
            case .back: return AppColors.orange
            case .garage: return AppColors.green
            case .bikeRack: return AppColors.zonePurpleDeep
            case .unassigned: return Color.secondary
            default: return LoadZone.resolved(rawValue: rawValue, for: .motorhome).chipAccentColor(for: .motorhome)
            }
        case .caravan:
            switch self {
            case .frontLocker: return AppColors.blue
            case .front: return AppColors.orange
            case .middle: return AppColors.pink
            case .rear: return AppColors.purple
            case .bikeRack: return AppColors.green
            case .unassigned: return Color.secondary
            default: return LoadZone.resolved(rawValue: rawValue, for: .caravan).chipAccentColor(for: .caravan)
            }
        }
    }

    /// Pastel fill behind zone labels (matches cutaway band colours on white).
    var chipPastelFill: Color {
        chipPastelFill(for: .caravan)
    }

    func chipPastelFill(for kind: VehicleKind) -> Color {
        switch kind {
        case .motorhome:
            switch self {
            case .driver, .back: return AppColors.zonePastelOrange
            case .central: return AppColors.zonePastelBlue
            case .garage: return AppColors.zonePastelGreen
            case .bikeRack: return AppColors.zonePastelPurpleDeep
            case .unassigned: return Color.secondary.opacity(0.12)
            default: return LoadZone.resolved(rawValue: rawValue, for: .motorhome).chipPastelFill(for: .motorhome)
            }
        case .caravan:
            switch self {
            case .frontLocker: return AppColors.zonePastelBlue
            case .front: return AppColors.zonePastelOrange
            case .middle: return AppColors.zonePastelPink
            case .rear: return AppColors.zonePastelPurple
            case .bikeRack: return AppColors.zonePastelGreen
            case .unassigned: return Color.secondary.opacity(0.12)
            default: return LoadZone.resolved(rawValue: rawValue, for: .caravan).chipPastelFill(for: .caravan)
            }
        }
    }
}
