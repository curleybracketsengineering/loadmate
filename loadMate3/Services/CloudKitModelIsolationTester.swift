import CloudKit
import Combine
import CoreData
import Foundation
import SwiftData

struct CloudKitIsolationTestReport: Equatable {
    enum Status: String, Equatable {
        case notRun = "Not run"
        case running = "Running"
        case passed = "PASSED"
        case failed = "FAILED"
    }

    var testName = "AppState only"
    var status: Status = .notRun
    var startedAt: Date?
    var finishedAt: Date?
    var duration: String?
    var localStoreCreated = false
    var localSave: String = "not attempted"
    var insertedAppStateCount = 0
    var probeValue = ""
    var setup: String = "not seen"
    var export: String = "not seen"
    var importResult: String = "not seen"
    var errorSummary: String?
    var deepErrorDump: String?
    var conclusion = "Not run"

    var formatted: String {
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
            "  AppState only",
            "",
            "Inserted:",
            "  AppState = \(insertedAppStateCount)",
            "  All other model types = not present in this ModelContainer",
            "",
            "Local save:",
            "  \(localSave)",
            "",
            "CloudKit:",
            "  SETUP \(setup)",
            "  IMPORT \(importResult)",
            "  EXPORT \(export)",
        ]
        if let errorSummary, !errorSummary.isEmpty {
            lines.append("")
            lines.append("Error:")
            lines.append("  \(errorSummary)")
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

    private let defaultsKey = "cloudKitIsolationTestReport"
    private var isolationContainer: ModelContainer?
    private var eventObserver: NSObjectProtocol?
    private var productionStoreIDs: Set<String> = []
    private var isolationStoreIDs: Set<String> = []

    @Published private(set) var lastFormattedReport: String = "Not run"

    private init() {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey + ".full") {
            lastFormattedReport = stored
            report.status = stored.contains("Status: PASSED") ? .passed
                : stored.contains("Status: FAILED") ? .failed
                : .notRun
        }
    }

    func runAppStateOnlyTest() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        tearDownIsolationResources()
        productionStoreIDs = CloudSyncMonitor.shared.seenCloudKitStoreIdentifiers
        CloudSyncMonitor.shared.beginIgnoringNonProductionCloudKitStores(productionStoreIDs: productionStoreIDs)

        var next = CloudKitIsolationTestReport()
        next.status = .running
        next.startedAt = Date()
        report = next
        persist(next)
        SyncDebugLogger.shared.record(category: "isolation", message: "Starting AppState-only CloudKit isolation test.")

        observeIsolationEvents()

        do {
            try LoadMateModelContainer.removeAppStateOnlyIsolationStoreIfPresent()
            isolationContainer = try LoadMateModelContainer.makeAppStateOnlyIsolationContainer()
            next.localStoreCreated = true
            report = next
        } catch {
            finish(
                next,
                status: .failed,
                errorSummary: "Failed to create isolation store: \(error.localizedDescription)",
                conclusion: failedConclusion()
            )
            return
        }

        let probeUUID = UUID()
        let probeValue = "appstate-isolation-\(probeUUID.uuidString)"
        next.probeValue = probeValue

        let context = ModelContext(isolationContainer!)
        let state = AppState(
            id: probeUUID,
            syncProbeSequence: 1,
            syncProbeValue: probeValue,
            syncProbeUpdatedAt: Date(),
            syncProbeUpdatedBy: "AppState isolation test"
        )
        context.insert(state)

        do {
            try context.save()
            var latest = report
            latest.localSave = "succeeded"
            latest.probeValue = probeValue
            latest.insertedAppStateCount = 1
            latest.localStoreCreated = true
            report = latest
            persist(latest)
            SyncDebugLogger.shared.record(
                category: "isolation",
                message: "Isolation local save succeeded. Probe: \(probeValue)"
            )
        } catch {
            var latest = report
            latest.localSave = "failed — \(error.localizedDescription)"
            latest.probeValue = probeValue
            latest.insertedAppStateCount = 1
            finish(
                latest,
                status: .failed,
                errorSummary: "Local save failed: \(error.localizedDescription)",
                conclusion: failedConclusion()
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
                    conclusion: failedConclusion()
                )
            } else if timedOut.export == "succeeded" {
                finish(timedOut, status: .passed, errorSummary: nil, conclusion: passedConclusion())
            } else if timedOut.export.hasPrefix("failed") {
                finish(
                    timedOut,
                    status: .failed,
                    errorSummary: timedOut.errorSummary ?? "EXPORT failed",
                    conclusion: failedConclusion()
                )
            } else {
                timedOut.errorSummary = "Timed out after \(Int(Self.timeoutSeconds))s waiting for CloudKit export (SETUP \(timedOut.setup), EXPORT \(timedOut.export))"
                finish(timedOut, status: .failed, errorSummary: timedOut.errorSummary, conclusion: failedConclusion())
            }
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
        if event.succeeded {
            apply(kind: kind, value: "succeeded", to: &next)
            SyncDebugLogger.shared.record(
                category: "isolation",
                message: "\(kind) succeeded in \(duration)"
            )
            if kind == "EXPORT" {
                finish(next, status: .passed, errorSummary: nil, conclusion: passedConclusion())
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
                    countsAtStart: "AppState=1 (isolation store)",
                    countsAtFailure: "AppState=1 (isolation store)",
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
                finish(next, status: .failed, errorSummary: next.errorSummary, conclusion: failedConclusion())
                return
            }
        }
        report = next
        persist(next)
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

    private func passedConclusion() -> String {
        """
        APPSTATE-ONLY TEST PASSED

        A CloudKit-backed SwiftData container containing only AppState successfully exported.

        This strongly suggests that the basic iCloud account, CloudKit container, entitlements and AppState model are functional.

        The failure in the normal application is therefore likely associated with one or more additional models or relationships in the full schema.
        """
    }

    private func failedConclusion() -> String {
        """
        APPSTATE-ONLY TEST FAILED

        Even a CloudKit-backed SwiftData container containing only AppState failed to export.

        Do not begin testing the remaining application models yet.

        Investigate CloudKit container/schema/environment/configuration before continuing model isolation.
        """
    }
}
