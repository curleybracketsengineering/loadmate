import SwiftUI

extension LoadZone {
    // MARK: Caravan zones

    static let caravanPickerZones: [LoadZone] = [.frontLocker, .front, .middle, .rear, .bikeRack]

    // MARK: Motorhome zones

    static let motorhomePickerZones: [LoadZone] = [.driver, .front, .central, .back, .garage]

    static func pickerZones(for kind: VehicleKind) -> [LoadZone] {
        kind == .motorhome ? motorhomePickerZones : caravanPickerZones
    }

    static var motorhomeGarageZone: LoadZone { .garage }

    /// Maps legacy caravan zone raw values stored on motorhome loads to motorhome zones.
    static func resolved(rawValue: String, for kind: VehicleKind) -> LoadZone {
        guard let zone = LoadZone(rawValue: rawValue) else { return .unassigned }
        guard kind == .motorhome else { return zone }
        switch zone {
        case .frontLocker: return .driver
        case .middle: return .central
        case .rear: return .back
        case .bikeRack: return .garage
        default: return zone
        }
    }

    /// Default zone when loading an item onto a profile (maps shared library defaults per kind).
    func defaultForLoading(on kind: VehicleKind) -> LoadZone {
        guard kind == .motorhome else { return self }
        switch self {
        case .frontLocker: return .driver
        case .middle: return .central
        case .rear: return .back
        case .bikeRack: return .garage
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
            case .driver: return "Driver"
            case .front: return "Front"
            case .central: return "Central"
            case .back: return "Back"
            case .garage: return "Garage"
            case .unassigned: return "Unassigned"
            default: return LoadZone.resolved(rawValue: rawValue, for: .motorhome).locationBadgeTitle(for: .motorhome)
            }
        }
    }

    /// Short labels for the motorhome position map so every box is the same size.
    func mapBadgeTitle(for kind: VehicleKind) -> String {
        guard kind == .motorhome else { return locationBadgeTitle(for: kind) }
        switch self {
        case .driver: return "Driver"
        case .front: return "Front"
        case .central: return "Mid."
        case .back: return "Back"
        case .garage: return "Gar."
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
            case .front: return "Above front axle"
            case .central: return "Between axles — shared"
            case .back: return "Above rear axle"
            case .garage: return "Behind rear axle — garage limit"
            case .unassigned: return ""
            default: return ""
            }
        }
    }

    var chipAccentColor: Color {
        switch self {
        case .frontLocker, .driver: AppColors.blue
        case .front: Color(red: 0.58, green: 0.29, blue: 0.91)
        case .middle, .central: Color(red: 1.0, green: 0.27, blue: 0.45)
        case .rear, .back: AppColors.orange
        case .bikeRack, .garage: AppColors.green
        case .unassigned: Color.secondary
        }
    }
}
