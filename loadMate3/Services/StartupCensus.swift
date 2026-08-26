import Foundation
import SwiftData

enum StartupCensus {
    static func counts(in context: ModelContext, includingGroups: Bool = true) -> String {
        let profiles = (try? context.fetch(FetchDescriptor<VehicleProfile>()).count) ?? 0
        let trips = (try? context.fetch(FetchDescriptor<Trip>()).count) ?? 0
        let sections = (try? context.fetch(FetchDescriptor<ChecklistSection>()).count) ?? 0
        let items = (try? context.fetch(FetchDescriptor<ChecklistItem>()).count) ?? 0
        let groups = includingGroups
            ? ((try? context.fetch(FetchDescriptor<ChecklistGroup>()).count) ?? 0)
            : 0
        return "profiles=\(profiles), trips=\(trips), checklistSections=\(sections), checklistGroups=\(groups), checklistItems=\(items)"
    }

    static func log(_ phase: String, in context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<VehicleProfile>()).count) ?? 0
        let trips = (try? context.fetch(FetchDescriptor<Trip>()).count) ?? 0
        let sections = (try? context.fetch(FetchDescriptor<ChecklistSection>()).count) ?? 0
        let items = (try? context.fetch(FetchDescriptor<ChecklistItem>()).count) ?? 0
        SyncDebugLogger.shared.record(
            category: "startup",
            message: """
            [\(phase)]
            VehicleProfiles = \(profiles)
            Trips = \(trips)
            ChecklistSections = \(sections)
            ChecklistItems = \(items)
            """
        )
    }
}
