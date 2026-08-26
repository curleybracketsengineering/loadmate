import Combine
import Foundation
import SwiftData

struct CloudKitProductionHealthReport: Equatable {
    var generatedAt = Date()
    var accountStatus: String
    var setup: String
    var lastImport: String
    var lastExport: String
    var lastError: String
    var counts: String
    var recentEvents: [String]
    var unsyncedHint: String

    var formatted: String {
        (
            [
                "Production Sync Health Check",
                "Generated: \(SyncDebugFormatting.logDateFormatter.string(from: generatedAt))",
                "This test does not create records.",
                "",
                "iCloud account: \(accountStatus)",
                "CloudKit setup: \(setup)",
                "Last import: \(lastImport)",
                "Last export: \(lastExport)",
                "Last error: \(lastError)",
                "Unsynced local changes: \(unsyncedHint)",
                "Counts: \(counts)",
                "",
                "Recent CloudKit events:",
            ] + (recentEvents.isEmpty ? ["  none"] : recentEvents.map { "  \($0)" })
        ).joined(separator: "\n")
    }
}

@MainActor
final class CloudKitDeletionSyncVerifier: ObservableObject {
    static let shared = CloudKitDeletionSyncVerifier()

    @Published var watchedID: UUID?
    @Published var watchedName = ""
    @Published var countsBefore = ""
    @Published var countsAfterLocalDelete = ""
    @Published var localDeleteObserved = false
    @Published var exportSucceededAfterDelete: Bool?
    @Published var reimported: Bool?
    @Published var reportText = "Not watching a deletion."

    private var watching = false
    private var exportSeen = false

    private init() {}

    func startWatching(profile: VehicleProfile, counts: SyncDebugEntityCounts) {
        watchedID = profile.id
        watchedName = ""
        countsBefore = counts.logLine
        countsAfterLocalDelete = ""
        localDeleteObserved = false
        exportSucceededAfterDelete = nil
        reimported = nil
        watching = true
        exportSeen = false
        reportText = """
        Watching vehicle \(profile.id.uuidString)
        Delete it in Settings using the normal UI.
        Counts before: \(countsBefore)
        """
        SyncDebugLogger.shared.record(
            category: "deletion",
            message: "[deletion-watch] watching VehicleProfile \(profile.id.uuidString)"
        )
    }

    func noteLocalDeletion(of profileID: UUID, counts: SyncDebugEntityCounts) {
        guard watching, watchedID == profileID else { return }
        localDeleteObserved = true
        countsAfterLocalDelete = counts.logLine
        append("Deletion local: succeeded\nCounts after: \(countsAfterLocalDelete)")
        SyncDebugLogger.shared.record(
            category: "deletion",
            message: "[deletion-watch] local delete observed for \(profileID.uuidString)"
        )
    }

    func noteExport(succeeded: Bool) {
        guard watching, localDeleteObserved, exportSucceededAfterDelete == nil else { return }
        exportSucceededAfterDelete = succeeded
        exportSeen = succeeded
        append("CloudKit deletion export: \(succeeded ? "succeeded" : "failed")")
    }

    func noteImport(in context: ModelContext) {
        guard watching, localDeleteObserved, exportSeen else { return }
        checkReimport(in: context)
    }

    func checkReimport(in context: ModelContext) {
        guard watching, let watchedID else { return }
        if !localDeleteObserved {
            append("Local deletion has not been observed yet.")
            return
        }
        if exportSucceededAfterDelete != true {
            append("CloudKit deletion export: not yet observed as succeeded")
        }
        let profiles = (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
        let returned = profiles.contains { $0.id == watchedID }
        reimported = returned
        append("Vehicle re-imported: \(returned ? "Yes" : "No")")
        SyncDebugLogger.shared.record(
            category: "deletion",
            message: "[deletion-watch] import check re-imported=\(returned) id=\(watchedID.uuidString)"
        )
    }

    func formattedStatus() -> String {
        reportText
    }

    private func append(_ line: String) {
        reportText += "\n\(line)"
    }
}

enum CloudKitProductionHealth {
    @MainActor
    static func report(monitor: CloudSyncMonitor, context: ModelContext) -> CloudKitProductionHealthReport {
        let counts = SyncDebugEntityCounts.fetch(from: context)
        let lastSetup = monitor.recentSyncEvents.first { $0.kind == .setup }
        let unsynced: String
        if monitor.lastSuccessfulExportAt == nil {
            unsynced = "unknown — no successful export recorded on this device"
        } else if monitor.lastErrorDescription != nil, monitor.lastSyncEvent?.kind == .exportToCloud, monitor.lastSyncEvent?.succeeded == false {
            unsynced = "likely — last export failed"
        } else {
            unsynced = "not detected from CloudKit events (SwiftData does not expose a pending-change count)"
        }
        return CloudKitProductionHealthReport(
            accountStatus: monitor.accountStatus.settingsTitle,
            setup: lastSetup?.context ?? "not seen in history",
            lastImport: SyncDebugFormatting.string(for: monitor.lastSuccessfulImportAt),
            lastExport: SyncDebugFormatting.string(for: monitor.lastSuccessfulExportAt),
            lastError: monitor.lastErrorDescription ?? "None",
            counts: counts.logLine,
            recentEvents: monitor.recentSyncEvents.prefix(12).map(\.displayLine),
            unsyncedHint: unsynced
        )
    }
}
