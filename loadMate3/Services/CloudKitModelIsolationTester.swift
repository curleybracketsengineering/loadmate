import CloudKit
import Combine
import CoreData
import Foundation
import SwiftData

enum CloudKitIsolationScenario: String, Equatable {
    case appStateOnly
    case coreVehicle
    case checklist

    var testName: String {
        switch self {
        case .appStateOnly: return "AppState only"
        case .coreVehicle: return "AppState + VehicleProfile + Trip"
        case .checklist: return "AppState + VehicleProfile + Trip + ChecklistSection + ChecklistItem"
        }
    }

    var storeName: String {
        switch self {
        case .appStateOnly: return "AppStateOnly"
        case .coreVehicle: return "CoreVehicle"
        case .checklist: return "ChecklistModel"
        }
    }

    var schema: Schema {
        switch self {
        case .appStateOnly: return LoadMateModelContainer.appStateOnlyIsolationSchema
        case .coreVehicle: return LoadMateModelContainer.coreVehicleIsolationSchema
        case .checklist: return LoadMateModelContainer.checklistIsolationSchema
        }
    }

    var modelContainerLines: [String] {
        switch self {
        case .appStateOnly:
            return ["  AppState"]
        case .coreVehicle:
            return ["  AppState", "  VehicleProfile", "  Trip"]
        case .checklist:
            return [
                "  Requested: AppState, VehicleProfile, Trip, ChecklistSection, ChecklistItem",
                "  Also registered by SwiftData as relationship destinations (0 records inserted): ChecklistGroup, LoadedItem, LibraryItem",
            ]
        }
    }

    var relationshipLines: [String] {
        switch self {
        case .appStateOnly:
            return ["  none"]
        case .coreVehicle:
            return [
                "  Trip.profile -> VehicleProfile",
                "  VehicleProfile.trips -> Trip",
            ]
        case .checklist:
            return [
                "  Trip.profile -> VehicleProfile",
                "  VehicleProfile.trips -> Trip",
                "  ChecklistSection.items -> ChecklistItem",
                "  ChecklistItem.section -> ChecklistSection",
                "  ChecklistItem.group -> ChecklistGroup (not populated; 0 ChecklistGroup records)",
                "  ChecklistSection.groups -> ChecklistGroup (not populated; 0 ChecklistGroup records)",
                "  ChecklistSection / ChecklistItem have no relationship to AppState, VehicleProfile, or Trip",
            ]
        }
    }

    var includesCoreVehicleModels: Bool {
        self == .coreVehicle || self == .checklist
    }

    var includesChecklistModels: Bool {
        self == .checklist
    }
}

struct CloudKitIsolationTestReport: Equatable {
    enum Status: String, Equatable {
        case notRun = "Not run"
        case running = "Running"
        case passed = "PASSED"
        case failed = "FAILED"
        case timedOut = "TIMED OUT"
    }

    var scenario: CloudKitIsolationScenario = .appStateOnly
    var testName = "AppState only"
    var status: Status = .notRun
    var startedAt: Date?
    var finishedAt: Date?
    var duration: String?
    var localStoreCreated = false
    var localSave: String = "not attempted"
    var insertedAppStateCount = 0
    var insertedVehicleProfileCount = 0
    var insertedTripCount = 0
    var insertedChecklistSectionCount = 0
    var insertedChecklistItemCount = 0
    var modelContainerLines: [String] = ["  AppState"]
    var relationshipLines: [String] = ["  none"]
    var probeValue = ""
    var setup: String = "not seen"
    var export: String = "not seen"
    var importResult: String = "not seen"
    var errorSummary: String?
    var deepErrorDump: String?
    var conclusion = "Not run"

    var formatted: String {
        var inserted = [
            "  AppState = \(insertedAppStateCount)",
        ]
        switch scenario {
        case .appStateOnly:
            inserted.append("  All other model types = not present in this ModelContainer")
        case .coreVehicle:
            inserted.append("  VehicleProfile = \(insertedVehicleProfileCount)")
            inserted.append("  Trip = \(insertedTripCount)")
        case .checklist:
            inserted.append("  VehicleProfile = \(insertedVehicleProfileCount)")
            inserted.append("  Trip = \(insertedTripCount)")
            inserted.append("  ChecklistSection = \(insertedChecklistSectionCount)")
            inserted.append("  ChecklistItem = \(insertedChecklistItemCount)")
            inserted.append("  ChecklistGroup = 0 (relationship destination only)")
        }

        var lines = [
            "CloudKit Model Isolation Test",
            "",
            "Test: \(testName)",
            "Status: \(status.rawValue)",
            "Started: \(startedAt.map { SyncDebugFormatting.logDateFormatter.string(from: $0) } ?? "—")",
            "Finished: \(finishedAt.map { SyncDebugFormatting.logDateFormatter.string(from: $0) } ?? "—")",
            "Duration: \(duration ?? "—")",
            "Local diagnostic store created: \(localStoreCreated ? "Yes" : "No")",
            "",
            "ModelContainer:",
        ]
        lines.append(contentsOf: modelContainerLines)
        lines.append("")
        lines.append("Inserted:")
        lines.append(contentsOf: inserted)
        lines.append("")
        lines.append("Relationships:")
        lines.append(contentsOf: relationshipLines)
        lines.append(contentsOf: [
            "",
            "Local save:",
            "  \(localSave)",
            "",
            "CloudKit:",
            "  SETUP \(setup)",
            "  IMPORT \(importResult)",
            "  EXPORT \(export)",
        ])
        if let errorSummary, !errorSummary.isEmpty {
            lines.append("")
            lines.append("Error:")
            lines.append("  \(errorSummary)")
        } else {
            lines.append("")
            lines.append("Error:")
            lines.append("  None")
        }
        if let deepErrorDump, !deepErrorDump.isEmpty {
            lines.append("")
            lines.append("Deep error inspection:")
            lines.append(deepErrorDump)
        }
        if !probeValue.isEmpty {
            lines.append("")
            lines.append("Probe:")
            lines.append("  \(probeValue)")
        }
        lines.append("")
        lines.append("Conclusion:")
        lines.append("  \(conclusion)")
        return lines.joined(separator: "\n")
    }
}

@MainActor
final class CloudKitModelIsolationTester: ObservableObject {
    static let shared = CloudKitModelIsolationTester()

    static let timeoutSeconds: TimeInterval = 90

    @Published private(set) var report = CloudKitIsolationTestReport()
    @Published private(set) var isRunning = false
    @Published private(set) var lastFormattedReport: String = "Not run"

    private let defaultsKey = "cloudKitIsolationTestReport"
    private var isolationContainer: ModelContainer?
    private var eventObserver: NSObjectProtocol?
    private var productionStoreIDs: Set<String> = []
    private var isolationStoreIDs: Set<String> = []
    private var currentScenario: CloudKitIsolationScenario = .appStateOnly

    private init() {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey + ".full") {
            lastFormattedReport = stored
            report.status = stored.contains("Status: PASSED") ? .passed
                : stored.contains("Status: FAILED") ? .failed
                : stored.contains("Status: TIMED OUT") ? .timedOut
                : .notRun
            if stored.contains("ChecklistSection + ChecklistItem") {
                report.scenario = .checklist
                report.testName = CloudKitIsolationScenario.checklist.testName
            } else if stored.contains("AppState + VehicleProfile + Trip") {
                report.scenario = .coreVehicle
                report.testName = CloudKitIsolationScenario.coreVehicle.testName
            }
        }
    }

    func runAppStateOnlyTest() async {
        await run(.appStateOnly)
    }

    func runCoreVehicleTest() async {
        await run(.coreVehicle)
    }

    func runChecklistTest() async {
        await run(.checklist)
    }

    private func run(_ scenario: CloudKitIsolationScenario) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        currentScenario = scenario
        tearDownIsolationResources()
        productionStoreIDs = CloudSyncMonitor.shared.seenCloudKitStoreIdentifiers
        CloudSyncMonitor.shared.beginIgnoringNonProductionCloudKitStores(productionStoreIDs: productionStoreIDs)

        var next = CloudKitIsolationTestReport()
        next.scenario = scenario
        next.testName = scenario.testName
        next.modelContainerLines = scenario.modelContainerLines
        next.relationshipLines = scenario.relationshipLines
        next.status = .running
        next.startedAt = Date()
        report = next
        persist(next)
        logStart(scenario)

        observeIsolationEvents()

        do {
            try LoadMateModelContainer.removeIsolationStoreIfPresent(named: scenario.storeName)
            isolationContainer = try LoadMateModelContainer.makeIsolationContainer(
                named: scenario.storeName,
                schema: scenario.schema
            )
            next.localStoreCreated = true
            report = next
        } catch {
            next.errorSummary = "Failed to create isolation store: \(error.localizedDescription)"
            finish(
                next,
                status: .failed,
                errorSummary: next.errorSummary,
                conclusion: failedConclusion(for: scenario, report: next)
            )
            return
        }

        let probeUUID = UUID()
        let probeValue: String
        switch scenario {
        case .appStateOnly:
            probeValue = "appstate-isolation-\(probeUUID.uuidString)"
        case .coreVehicle:
            probeValue = "core-vehicle-isolation-\(probeUUID.uuidString)"
        case .checklist:
            probeValue = "checklist-isolation-\(probeUUID.uuidString)"
        }

        let context = ModelContext(isolationContainer!)
        do {
            try insertData(for: scenario, in: context, probeUUID: probeUUID, probeValue: probeValue)
            try context.save()
            var latest = report
            latest.localSave = "succeeded"
            latest.probeValue = probeValue
            latest.insertedAppStateCount = 1
            if scenario.includesCoreVehicleModels {
                latest.insertedVehicleProfileCount = 1
                latest.insertedTripCount = 1
            }
            if scenario.includesChecklistModels {
                latest.insertedChecklistSectionCount = 1
                latest.insertedChecklistItemCount = 1
            }
            latest.localStoreCreated = true
            report = latest
            persist(latest)
            SyncDebugLogger.shared.record(category: "isolation", message: "Local save succeeded")
        } catch {
            var latest = report
            latest.localSave = "failed — \(error.localizedDescription)"
            latest.probeValue = probeValue
            latest.insertedAppStateCount = 1
            if scenario.includesCoreVehicleModels {
                latest.insertedVehicleProfileCount = 1
                latest.insertedTripCount = 1
            }
            if scenario.includesChecklistModels {
                latest.insertedChecklistSectionCount = 1
                latest.insertedChecklistItemCount = 1
            }
            finish(
                latest,
                status: .failed,
                errorSummary: "Local save failed: \(error.localizedDescription)",
                conclusion: failedConclusion(for: scenario, report: latest)
            )
            return
        }

        let deadline = Date().addingTimeInterval(Self.timeoutSeconds)
        while Date() < deadline {
            if Task.isCancelled { break }
            let current = report
            if current.status != .running { break }
            if exportHasFinished(current) || setupFailed(current) { break }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        if report.status == .running {
            var timedOut = report
            if setupFailed(timedOut) {
                finish(
                    timedOut,
                    status: .failed,
                    errorSummary: timedOut.errorSummary ?? "SETUP failed",
                    conclusion: failedConclusion(for: scenario, report: timedOut)
                )
            } else if timedOut.export == "succeeded" {
                finish(timedOut, status: .passed, errorSummary: nil, conclusion: passedConclusion(for: scenario))
            } else if timedOut.export.hasPrefix("failed") {
                finish(
                    timedOut,
                    status: .failed,
                    errorSummary: timedOut.errorSummary ?? "EXPORT failed",
                    conclusion: failedConclusion(for: scenario, report: timedOut)
                )
            } else {
                timedOut.errorSummary = "Timed out after \(Int(Self.timeoutSeconds))s waiting for CloudKit export (SETUP \(timedOut.setup), EXPORT \(timedOut.export))"
                finish(
                    timedOut,
                    status: .timedOut,
                    errorSummary: timedOut.errorSummary,
                    conclusion: timedOutConclusion(for: scenario)
                )
            }
        }
    }

    private func insertData(
        for scenario: CloudKitIsolationScenario,
        in context: ModelContext,
        probeUUID: UUID,
        probeValue: String
    ) throws {
        let updatedBy: String
        switch scenario {
        case .appStateOnly: updatedBy = "AppState isolation test"
        case .coreVehicle: updatedBy = "Core vehicle isolation test"
        case .checklist: updatedBy = "Checklist model isolation test"
        }
        let state = AppState(
            id: probeUUID,
            syncProbeSequence: 1,
            syncProbeValue: probeValue,
            syncProbeUpdatedAt: Date(),
            syncProbeUpdatedBy: updatedBy
        )
        context.insert(state)
        SyncDebugLogger.shared.record(category: "isolation", message: "AppState inserted")

        guard scenario.includesCoreVehicleModels else { return }

        let profile = VehicleProfile(
            name: "CloudKit Test Vehicle",
            kind: .caravan,
            sortOrder: 0
        )
        context.insert(profile)
        SyncDebugLogger.shared.record(category: "isolation", message: "VehicleProfile inserted")

        let trip = Trip(
            name: "CloudKit Test Trip",
            sortOrder: 0,
            profile: profile
        )
        context.insert(trip)
        profile.activeTripID = trip.id
        SyncDebugLogger.shared.record(category: "isolation", message: "Trip inserted")
        SyncDebugLogger.shared.record(
            category: "isolation",
            message: "Profile/Trip relationship established"
        )

        guard scenario.includesChecklistModels else { return }

        let section = ChecklistSection(title: "CloudKit Test Section", sortOrder: 0)
        context.insert(section)
        let item = ChecklistItem(
            title: "CloudKit Test Item",
            isChecked: false,
            sortOrder: 0,
            section: section
        )
        context.insert(item)
        SyncDebugLogger.shared.record(category: "isolation", message: "ChecklistSection inserted")
        SyncDebugLogger.shared.record(category: "isolation", message: "ChecklistItem inserted")
        SyncDebugLogger.shared.record(
            category: "isolation",
            message: "ChecklistSection.items / ChecklistItem.section relationship established"
        )
    }

    private func logStart(_ scenario: CloudKitIsolationScenario) {
        switch scenario {
        case .appStateOnly:
            SyncDebugLogger.shared.record(category: "isolation", message: "Starting AppState-only CloudKit isolation test.")
        case .coreVehicle:
            SyncDebugLogger.shared.record(category: "isolation", message: "Core vehicle isolation test started")
        case .checklist:
            SyncDebugLogger.shared.record(category: "isolation", message: "Checklist model isolation test started")
        }
    }

    private func observeIsolationEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else { return }
            Task { @MainActor [weak self] in
                self?.handleIsolationEvent(event)
            }
        }
    }

    private func handleIsolationEvent(_ event: NSPersistentCloudKitContainer.Event) {
        guard report.status == .running else { return }
        if productionStoreIDs.contains(event.storeIdentifier) {
            return
        }
        isolationStoreIDs.insert(event.storeIdentifier)

        let kind: String
        switch event.type {
        case .setup: kind = "SETUP"
        case .import: kind = "IMPORT"
        case .export: kind = "EXPORT"
        @unknown default: kind = "UNKNOWN"
        }

        let started = event.endDate == nil
        var next = report
        if started {
            apply(kind: kind, value: "started", to: &next)
            let timestamp = SyncDebugFormatting.logDateFormatter.string(from: event.startDate)
            SyncDebugLogger.shared.record(
                category: "isolation",
                message: "\(kind) started at \(timestamp)"
            )
            report = next
            persist(next)
            return
        }

        let finishedAt = event.endDate ?? Date()
        let duration = String(format: "%.1fms", finishedAt.timeIntervalSince(event.startDate) * 1000)
        let counts = countLine(for: currentScenario)
        if event.succeeded {
            apply(kind: kind, value: "succeeded", to: &next)
            SyncDebugLogger.shared.record(
                category: "isolation",
                message: "\(kind) succeeded in \(duration)"
            )
            if kind == "EXPORT" {
                finish(next, status: .passed, errorSummary: nil, conclusion: passedConclusion(for: currentScenario))
                return
            }
        } else {
            let dump = CloudKitDeepErrorInspector.inspect(
                error: event.error,
                context: CloudKitDeepErrorInspector.EventContext(
                    kind: kind,
                    succeeded: false,
                    startDate: event.startDate,
                    endDate: finishedAt,
                    identifier: event.identifier.uuidString,
                    storeIdentifier: event.storeIdentifier,
                    notificationKeys: [],
                    extraNotificationErrors: [],
                    countsAtStart: counts,
                    countsAtFailure: counts,
                    duration: duration,
                    uptimeSeconds: ProcessInfo.processInfo.systemUptime,
                    pendingMinimalSyncTestID: nil
                )
            )
            apply(kind: kind, value: "failed", to: &next)
            next.deepErrorDump = dump
            next.errorSummary = event.error.map { CloudSyncErrorFormatting.description(for: $0) }
                ?? "\(kind) failed without an error description"
            SyncDebugLogger.shared.record(
                category: "isolation",
                message: "\(kind) failed in \(duration)\n\(dump)"
            )
            if kind == "EXPORT" || kind == "SETUP" {
                finish(
                    next,
                    status: .failed,
                    errorSummary: next.errorSummary,
                    conclusion: failedConclusion(for: currentScenario, report: next)
                )
                return
            }
        }
        report = next
        persist(next)
    }

    private func countLine(for scenario: CloudKitIsolationScenario) -> String {
        switch scenario {
        case .appStateOnly:
            return "AppState=1 (isolation store)"
        case .coreVehicle:
            return "AppState=1, VehicleProfile=1, Trip=1 (isolation store)"
        case .checklist:
            return "AppState=1, VehicleProfile=1, Trip=1, ChecklistSection=1, ChecklistItem=1 (isolation store)"
        }
    }

    private func apply(kind: String, value: String, to report: inout CloudKitIsolationTestReport) {
        switch kind {
        case "SETUP": report.setup = value
        case "IMPORT": report.importResult = value
        case "EXPORT": report.export = value
        default: break
        }
    }

    private func exportHasFinished(_ report: CloudKitIsolationTestReport) -> Bool {
        report.export == "succeeded" || report.export.hasPrefix("failed")
    }

    private func setupFailed(_ report: CloudKitIsolationTestReport) -> Bool {
        report.setup.hasPrefix("failed")
    }

    private func finish(
        _ current: CloudKitIsolationTestReport,
        status: CloudKitIsolationTestReport.Status,
        errorSummary: String?,
        conclusion: String
    ) {
        guard report.status == .running else { return }
        var next = current
        next.status = status
        next.finishedAt = Date()
        if let started = next.startedAt, let finished = next.finishedAt {
            next.duration = String(format: "%.1fs", finished.timeIntervalSince(started))
        }
        next.errorSummary = errorSummary
        next.conclusion = conclusion
        report = next
        persist(next)
        SyncDebugLogger.shared.record(category: "isolation", message: conclusion)
        tearDownIsolationResources()
    }

    private func tearDownIsolationResources() {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
            self.eventObserver = nil
        }
        CloudSyncMonitor.shared.endIgnoringNonProductionCloudKitStores()
        isolationContainer = nil
        isolationStoreIDs = []
    }

    private func persist(_ report: CloudKitIsolationTestReport) {
        lastFormattedReport = report.formatted
        UserDefaults.standard.set(report.formatted, forKey: defaultsKey + ".full")
        UserDefaults.standard.set(report.conclusion, forKey: defaultsKey)
    }

    private func passedConclusion(for scenario: CloudKitIsolationScenario) -> String {
        switch scenario {
        case .appStateOnly:
            return """
            APPSTATE-ONLY TEST PASSED

            A CloudKit-backed SwiftData container containing only AppState successfully exported.

            This strongly suggests that the basic iCloud account, CloudKit container, entitlements and AppState model are functional.

            The failure in the normal application is therefore likely associated with one or more additional models or relationships in the full schema.
            """
        case .coreVehicle:
            return """
            CORE VEHICLE TEST PASSED

            AppState + VehicleProfile + Trip exported successfully.

            This suggests that:
            - AppState is CloudKit-compatible
            - VehicleProfile is CloudKit-compatible
            - Trip is CloudKit-compatible
            - the VehicleProfile/Trip relationship is CloudKit-compatible

            The failure in the full application likely lies in another model group.
            """
        case .checklist:
            return """
            CHECKLIST MODEL TEST PASSED

            AppState + VehicleProfile + Trip + ChecklistSection + ChecklistItem exported successfully.

            This suggests that:
            - ChecklistSection is CloudKit-compatible
            - ChecklistItem is CloudKit-compatible
            - their tested relationship(s) are CloudKit-compatible

            SwiftData also registered ChecklistGroup, LoadedItem, and LibraryItem as relationship destinations; this test inserted 0 of those records.

            This does not prove that the normal 5-section / 68-item production seed is safe. It proves only that the model structure and the tested minimal records can export.
            """
        }
    }

    private func failedConclusion(for scenario: CloudKitIsolationScenario, report current: CloudKitIsolationTestReport) -> String {
        switch scenario {
        case .appStateOnly:
            return """
            APPSTATE-ONLY TEST FAILED

            Even a CloudKit-backed SwiftData container containing only AppState failed to export.

            Do not begin testing the remaining application models yet.

            Investigate CloudKit container/schema/environment/configuration before continuing model isolation.
            """
        case .coreVehicle:
            return """
            CORE VEHICLE TEST FAILED

            AppState-only previously passed, but AppState + VehicleProfile + Trip failed.

            The likely fault is now narrowed to:
            - VehicleProfile
            - Trip
            - their relationship
            - or their CloudKit schema representation

            Do not add more model groups yet.
            """
        case .checklist:
            let exportBegan = current.export != "not seen"
            return """
            CHECKLIST MODEL TEST FAILED

            Core vehicle previously passed, but AppState + VehicleProfile + Trip + ChecklistSection + ChecklistItem failed.

            Local save: \(current.localSave)
            CloudKit setup: \(current.setup)
            Export began: \(exportBegan ? "yes (\(current.export))" : "no")
            CloudKit export: \(current.export)
            Error: \(current.errorSummary ?? "None")
            Model counts: AppState=\(current.insertedAppStateCount), VehicleProfile=\(current.insertedVehicleProfileCount), Trip=\(current.insertedTripCount), ChecklistSection=\(current.insertedChecklistSectionCount), ChecklistItem=\(current.insertedChecklistItemCount)
            Relationships used:
            \(current.relationshipLines.joined(separator: "\n"))

            The likely fault is now narrowed to ChecklistSection, ChecklistItem, empty ChecklistGroup as a schema destination, their tested relationship(s), or their CloudKit schema representation.

            Do not change production models in this step.
            """
        }
    }

    private func timedOutConclusion(for scenario: CloudKitIsolationScenario) -> String {
        switch scenario {
        case .appStateOnly:
            return """
            APPSTATE-ONLY TEST TIMED OUT

            No definitive CloudKit export result was observed within \(Int(Self.timeoutSeconds)) seconds.
            """
        case .coreVehicle:
            return """
            CORE VEHICLE TEST TIMED OUT

            No definitive CloudKit export result was observed within \(Int(Self.timeoutSeconds)) seconds.

            Do not add more model groups yet.
            """
        case .checklist:
            return """
            CHECKLIST MODEL TEST TIMED OUT

            No definitive CloudKit export result was observed within \(Int(Self.timeoutSeconds)) seconds.

            Local save is not CloudKit success. Do not change production models in this step.
            """
        }
    }
}
