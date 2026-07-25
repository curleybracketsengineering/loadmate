import SwiftData
import SwiftUI

struct SyncDebugPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @ObservedObject var cloudSync: CloudSyncMonitor

    let appState: AppState?
    let activeProfileName: String?

    @ObservedObject private var logger = SyncDebugLogger.shared
    @State private var counts = Counts()
    @State private var copyConfirmation = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "ladybug",
                        title: "Sync Debug",
                        subtitle: "Hidden developer-only iCloud diagnostics"
                    )

                    statusSection()
                    probeSection()
                    countsSection()
                    actionsSection()
                    logSection()
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Sync Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                refreshCounts()
                cloudSync.refreshPushRegistrationStatus()
                SyncDebugLogger.shared.record(category: "panel", message: "Opened sync debug panel.")
            }
        }
    }

    @ViewBuilder
    private func statusSection() -> some View {
        AppSettingsSection(
            "Status",
            caption: "What this device currently knows about iCloud and the app build."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                statusRow("iCloud", value: cloudSync.accountStatus.settingsTitle)
                statusRow("Checked", value: SyncDebugFormatting.string(for: cloudSync.lastCheckedAt))
                statusRow("Last error", value: cloudSync.lastErrorDescription ?? "None")
                statusRow("Last CloudKit event", value: lastSyncEventText)
                statusRow("Last import OK", value: SyncDebugFormatting.string(for: cloudSync.lastSuccessfulImportAt))
                statusRow("Last export OK", value: SyncDebugFormatting.string(for: cloudSync.lastSuccessfulExportAt))
                statusRow("Push registered", value: cloudSync.isRegisteredForRemoteNotifications ? "Yes" : "No")
                statusRow("Push detail", value: cloudSync.pushRegistrationDetail)
                statusRow("CloudKit schema", value: cloudSync.cloudKitSchemaDetail)
                statusRow("Device", value: SyncDebugFormatting.deviceName)
                statusRow("Bundle", value: SyncDebugFormatting.bundleID)
                statusRow("Version", value: "\(SyncDebugFormatting.appVersion) (\(SyncDebugFormatting.buildNumber))")
                statusRow("CloudKit", value: LoadMateModelContainer.cloudKitContainerID)
                statusRow("Active profile", value: activeProfileName ?? "None")
            }
        }
    }

    @ViewBuilder
    private func probeSection() -> some View {
        AppSettingsSection(
            "Sync Probe",
            caption: "Write this marker on one device and check whether the other device imports it."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                statusRow("Sequence", value: "\(appState?.syncProbeSequence ?? 0)")
                statusRow("Updated", value: SyncDebugFormatting.string(for: appState?.syncProbeUpdatedAt))
                statusRow("Device", value: probeDeviceText)
                statusRow("Value", value: probeValueText)

                AppSecondaryButton("Write Sync Probe") {
                    writeSyncProbe()
                }
            }
        }
    }

    @ViewBuilder
    private func countsSection() -> some View {
        AppSettingsSection(
            "Entity Counts",
            caption: "Use these counts to spot missing imports or duplicate local state."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                statusRow("Vehicle profiles", value: "\(counts.vehicleProfiles)")
                statusRow("Trips", value: "\(counts.trips)")
                statusRow("Loaded items", value: "\(counts.loadedItems)")
                statusRow("Library items", value: "\(counts.libraryItems)")
                statusRow("Checklist sections", value: "\(counts.checklistSections)")
                statusRow("Checklist items", value: "\(counts.checklistItems)")
                statusRow("AppState rows", value: "\(counts.appStates)")
            }
        }
    }

    @ViewBuilder
    private func actionsSection() -> some View {
        AppSettingsSection(
            "Actions",
            caption: "Manual refresh and reporting tools for real-device troubleshooting."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                AppSecondaryButton("Refresh iCloud Status") {
                    Task {
                        await cloudSync.refresh()
                        refreshCounts()
                    }
                }

                AppSecondaryButton("Check CloudKit Schema") {
                    Task {
                        await cloudSync.probeCloudKitSchema()
                    }
                }

                AppSecondaryButton("Copy Debug Report") {
                    refreshCounts()
                    let report = logger.makeReport(snapshot: snapshot())
                    copyConfirmation = logger.copyReport(report) ? "Report copied to clipboard." : "Clipboard not available on this platform."
                }

                AppSecondaryButton("Clear Local Log") {
                    logger.clear()
                    copyConfirmation = "Cleared local sync log."
                }

                if !copyConfirmation.isEmpty {
                    Text(copyConfirmation)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }
            }
        }
    }

    @ViewBuilder
    private func logSection() -> some View {
        AppSettingsSection(
            "Recent Log",
            caption: "Local rolling log of save attempts, probe writes, and iCloud checks."
        ) {
            if logger.entries.isEmpty {
                Text("No log entries yet.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(logger.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("[\(entry.category.uppercased())] \(SyncDebugFormatting.string(for: entry.timestamp))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                            Text(entry.message)
                                .font(.caption)
                                .foregroundStyle(Color.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if entry.id != logger.entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func writeSyncProbe() {
        guard let appState else { return }

        let sequence = appState.syncProbeSequence + 1
        let deviceName = SyncDebugFormatting.deviceName
        let timestamp = Date()

        appState.syncProbeSequence = sequence
        appState.syncProbeUpdatedAt = timestamp
        appState.syncProbeUpdatedBy = deviceName
        appState.syncProbeValue = "\(deviceName) @ \(SyncDebugFormatting.displayDateFormatter.string(from: timestamp))"

        if SyncDebugSaveHelper.save(modelContext, source: "SyncDebugPanel.writeSyncProbe") {
            logger.record(
                category: "probe",
                message: "Wrote sync probe #\(sequence) from \(deviceName)."
            )
            refreshCounts()
        }
    }

    private func refreshCounts() {
        counts = Counts(
            vehicleProfiles: fetchCount(FetchDescriptor<VehicleProfile>()),
            trips: fetchCount(FetchDescriptor<Trip>()),
            loadedItems: fetchCount(FetchDescriptor<LoadedItem>()),
            libraryItems: fetchCount(FetchDescriptor<LibraryItem>()),
            checklistSections: fetchCount(FetchDescriptor<ChecklistSection>()),
            checklistItems: fetchCount(FetchDescriptor<ChecklistItem>()),
            appStates: fetchCount(FetchDescriptor<AppState>())
        )
    }

    private func fetchCount<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> Int {
        (try? modelContext.fetch(descriptor).count) ?? 0
    }

    private func snapshot() -> SyncDebugSnapshot {
        SyncDebugSnapshot(
            accountStatus: cloudSync.accountStatus,
            lastCheckedAt: cloudSync.lastCheckedAt,
            lastErrorDescription: cloudSync.lastErrorDescription,
            lastSyncEventSummary: lastSyncEventText,
            lastSuccessfulImportAt: cloudSync.lastSuccessfulImportAt,
            lastSuccessfulExportAt: cloudSync.lastSuccessfulExportAt,
            isRegisteredForRemoteNotifications: cloudSync.isRegisteredForRemoteNotifications,
            pushRegistrationDetail: cloudSync.pushRegistrationDetail,
            cloudKitSchemaDetail: cloudSync.cloudKitSchemaDetail,
            deviceName: SyncDebugFormatting.deviceName,
            bundleID: SyncDebugFormatting.bundleID,
            appVersion: SyncDebugFormatting.appVersion,
            buildNumber: SyncDebugFormatting.buildNumber,
            vehicleProfileCount: counts.vehicleProfiles,
            tripCount: counts.trips,
            loadedItemCount: counts.loadedItems,
            libraryItemCount: counts.libraryItems,
            checklistSectionCount: counts.checklistSections,
            checklistItemCount: counts.checklistItems,
            appStateCount: counts.appStates,
            activeProfileName: activeProfileName,
            syncProbeSequence: appState?.syncProbeSequence ?? 0,
            syncProbeValue: appState?.syncProbeValue ?? "",
            syncProbeUpdatedAt: appState?.syncProbeUpdatedAt,
            syncProbeUpdatedBy: appState?.syncProbeUpdatedBy ?? ""
        )
    }

    private var lastSyncEventText: String {
        guard let event = cloudSync.lastSyncEvent else { return "None yet" }
        let result = event.succeeded ? "OK" : "FAILED"
        let when = SyncDebugFormatting.string(for: event.finishedAt)
        if let error = event.errorDescription, !error.isEmpty {
            return "\(event.kind.displayName) \(result) @ \(when) — \(error)"
        }
        return "\(event.kind.displayName) \(result) @ \(when)"
    }

    @ViewBuilder
    private func statusRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var probeDeviceText: String {
        guard let value = appState?.syncProbeUpdatedBy, !value.isEmpty else { return "None" }
        return value
    }

    private var probeValueText: String {
        guard let value = appState?.syncProbeValue, !value.isEmpty else { return "None" }
        return value
    }
}

private extension SyncDebugPanelView {
    struct Counts {
        var vehicleProfiles: Int = 0
        var trips: Int = 0
        var loadedItems: Int = 0
        var libraryItems: Int = 0
        var checklistSections: Int = 0
        var checklistItems: Int = 0
        var appStates: Int = 0
    }
}
