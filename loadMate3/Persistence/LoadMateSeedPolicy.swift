import Foundation

/// Controls first-launch factory data. Automatic vehicles and the factory checklist
/// are off so CloudKit tests start from an empty store. Users add vehicles in Settings.
enum LoadMateSeedPolicy {
    static let automaticVehicleAndChecklistSeedEnabled = false

    static var statusLine: String {
        automaticVehicleAndChecklistSeedEnabled
            ? "ENABLED (factory vehicles + checklist template)"
            : "DISABLED (no factory vehicles or checklist template)"
    }
}
