import Combine
import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct SyncDebugEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let category: String
    let message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), category: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }
}

struct SyncDebugSnapshot {
    let accountStatus: CloudSyncAccountStatus
    let lastCheckedAt: Date?
    let lastErrorDescription: String?
    let deviceName: String
    let bundleID: String
    let appVersion: String
    let buildNumber: String
    let vehicleProfileCount: Int
    let tripCount: Int
    let loadedItemCount: Int
    let libraryItemCount: Int
    let checklistSectionCount: Int
    let checklistItemCount: Int
    let appStateCount: Int
    let activeProfileName: String?
    let syncProbeSequence: Int
    let syncProbeValue: String
    let syncProbeUpdatedAt: Date?
    let syncProbeUpdatedBy: String
}

@MainActor
final class SyncDebugLogger: ObservableObject {
    static let shared = SyncDebugLogger()

    @Published private(set) var entries: [SyncDebugEntry] = []

    private let defaultsKey = "syncDebugEntries"
    private let maxEntries = 80
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? decoder.decode([SyncDebugEntry].self, from: data) {
            entries = decoded
        }
    }

    func record(category: String, message: String) {
        let entry = SyncDebugEntry(category: category, message: message)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    func copyReport(_ report: String) -> Bool {
        #if canImport(UIKit)
        UIPasteboard.general.string = report
        record(category: "share", message: "Copied sync debug report to clipboard.")
        return true
        #else
        return false
        #endif
    }

    func makeReport(snapshot: SyncDebugSnapshot) -> String {
        let formatter = SyncDebugFormatting.logDateFormatter
        let rows = [
            "Sync Debug Report",
            "Generated: \(formatter.string(from: Date()))",
            "Device: \(snapshot.deviceName)",
            "Bundle ID: \(snapshot.bundleID)",
            "Version: \(snapshot.appVersion) (\(snapshot.buildNumber))",
            "CloudKit container: \(LoadMateModelContainer.cloudKitContainerID)",
            "iCloud status: \(snapshot.accountStatus.settingsTitle)",
            "Last iCloud check: \(SyncDebugFormatting.string(for: snapshot.lastCheckedAt))",
            "Last iCloud error: \(snapshot.lastErrorDescription ?? "None")",
            "Active profile: \(snapshot.activeProfileName ?? "None")",
            "Counts: profiles=\(snapshot.vehicleProfileCount), trips=\(snapshot.tripCount), loadedItems=\(snapshot.loadedItemCount), libraryItems=\(snapshot.libraryItemCount), checklistSections=\(snapshot.checklistSectionCount), checklistItems=\(snapshot.checklistItemCount), appStates=\(snapshot.appStateCount)",
            "Sync probe sequence: \(snapshot.syncProbeSequence)",
            "Sync probe updated: \(SyncDebugFormatting.string(for: snapshot.syncProbeUpdatedAt))",
            "Sync probe device: \(snapshot.syncProbeUpdatedBy.isEmpty ? "None" : snapshot.syncProbeUpdatedBy)",
            "Sync probe value: \(snapshot.syncProbeValue.isEmpty ? "None" : snapshot.syncProbeValue)",
            "",
            "Recent log"
        ]

        let logLines = entries.map {
            "[\(formatter.string(from: $0.timestamp))] [\($0.category)] \($0.message)"
        }

        return (rows + logLines).joined(separator: "\n")
    }

    private func persist() {
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

enum SyncDebugSaveHelper {
    @discardableResult
    static func save(_ context: ModelContext, source: String) -> Bool {
        do {
            try context.save()
            Task { @MainActor in
                SyncDebugLogger.shared.record(category: "save", message: "\(source): save succeeded.")
            }
            return true
        } catch {
            Task { @MainActor in
                SyncDebugLogger.shared.record(
                    category: "save",
                    message: "\(source): save failed - \(error.localizedDescription)"
                )
            }
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
            return false
        }
    }
}

enum SyncDebugFormatting {
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    static let logDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(for date: Date?) -> String {
        guard let date else { return "Never" }
        return displayDateFormatter.string(from: date)
    }

    static var deviceName: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        ProcessInfo.processInfo.hostName
        #endif
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }
}
