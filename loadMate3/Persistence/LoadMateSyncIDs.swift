import Foundation

/// Stable identifiers shared across devices so CloudKit can deduplicate seeded records.
enum LoadMateSyncIDs {
    static let appState = UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!
    static let defaultCaravanProfile = UUID(uuidString: "A1000002-0000-4000-8000-000000000001")!
    static let defaultMotorhomeProfile = UUID(uuidString: "A1000002-0000-4000-8000-000000000002")!
    static let defaultCaravanTrip = UUID(uuidString: "A1000003-0000-4000-8000-000000000001")!
    static let defaultMotorhomeTrip = UUID(uuidString: "A1000003-0000-4000-8000-000000000002")!
}
