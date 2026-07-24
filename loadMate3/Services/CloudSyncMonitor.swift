import CloudKit
import Combine
import CoreData
import Foundation

enum CloudSyncAccountStatus: Equatable {
  case available
  case noAccount
  case restricted
  case couldNotDetermine
  case temporarilyUnavailable

  var settingsTitle: String {
    switch self {
    case .available: return "iCloud sync is on"
    case .noAccount: return "Sign in to iCloud"
    case .restricted: return "iCloud access restricted"
    case .couldNotDetermine: return "Checking iCloud…"
    case .temporarilyUnavailable: return "iCloud temporarily unavailable"
    }
  }

  var settingsDetail: String {
    switch self {
    case .available:
      return "Your vehicles, trips, load lists, and checklists stay up to date across your iPhone and iPad signed into the same Apple ID."
    case .noAccount:
      return "Open Settings → Apple Account and sign in to iCloud to sync Lyneqo Caravan & Motorhome between your devices."
    case .restricted:
      return "This device cannot use iCloud right now. Check Screen Time or device management restrictions."
    case .couldNotDetermine:
      return "Lyneqo Caravan & Motorhome will keep trying to reach iCloud."
    case .temporarilyUnavailable:
      return "iCloud is not reachable at the moment. Your data is saved on this device and will sync when iCloud is back."
    }
  }

  var systemImage: String {
    switch self {
    case .available: return "icloud.fill"
    case .noAccount: return "icloud.slash"
    case .restricted: return "lock.icloud"
    case .couldNotDetermine: return "icloud"
    case .temporarilyUnavailable: return "icloud.slash"
    }
  }
}

enum CloudSyncEventKind: String, Equatable {
  case setup
  case importFromCloud = "import"
  case exportToCloud = "export"
  case unknown

  var displayName: String {
    switch self {
    case .setup: return "Setup"
    case .importFromCloud: return "Import"
    case .exportToCloud: return "Export"
    case .unknown: return "Unknown"
    }
  }
}

struct CloudSyncEventSummary: Equatable {
  var kind: CloudSyncEventKind
  var succeeded: Bool
  var finishedAt: Date
  var errorDescription: String?
}

@MainActor
final class CloudSyncMonitor: ObservableObject {
  @Published private(set) var accountStatus: CloudSyncAccountStatus = .couldNotDetermine
  @Published private(set) var lastCheckedAt: Date?
  @Published private(set) var lastErrorDescription: String?
  @Published private(set) var lastSyncEvent: CloudSyncEventSummary?
  @Published private(set) var lastSuccessfulImportAt: Date?
  @Published private(set) var lastSuccessfulExportAt: Date?
  @Published private(set) var isObservingSyncEvents = false

  private var accountObserver: NSObjectProtocol?
  private var syncEventObserver: NSObjectProtocol?
  private var didStart = false

  init() {
    start()
  }

  deinit {
    if let accountObserver {
      NotificationCenter.default.removeObserver(accountObserver)
    }
    if let syncEventObserver {
      NotificationCenter.default.removeObserver(syncEventObserver)
    }
  }

  func start() {
    guard !didStart else { return }
    didStart = true
    observeAccountChanges()
    observeSyncEvents()
    Task { await refresh() }
  }

  func refresh() async {
    do {
      let status = try await CKContainer(identifier: LoadMateModelContainer.cloudKitContainerID)
        .accountStatus()
      accountStatus = map(status)
      lastErrorDescription = nil
      lastCheckedAt = Date()
      SyncDebugLogger.shared.record(
        category: "icloud",
        message: "Account status refreshed: \(accountStatus.settingsTitle)."
      )
    } catch {
      accountStatus = .couldNotDetermine
      lastErrorDescription = error.localizedDescription
      lastCheckedAt = Date()
      SyncDebugLogger.shared.record(
        category: "icloud",
        message: "Account status refresh failed: \(error.localizedDescription)"
      )
    }
  }

  private func observeAccountChanges() {
    accountObserver = NotificationCenter.default.addObserver(
      forName: .CKAccountChanged,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        SyncDebugLogger.shared.record(category: "icloud", message: "CKAccountChanged received.")
        await self?.refresh()
      }
    }
  }

  private func observeSyncEvents() {
    syncEventObserver = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
          as? NSPersistentCloudKitContainer.Event
      else { return }

      Task { @MainActor in
        self?.handleSyncEvent(event)
      }
    }
    isObservingSyncEvents = true
    SyncDebugLogger.shared.record(
      category: "icloud",
      message: "Observing CloudKit setup/import/export events."
    )
  }

  private func handleSyncEvent(_ event: NSPersistentCloudKitContainer.Event) {
    let kind = mapEventKind(event.type)
    let started = event.endDate == nil

    if started {
      SyncDebugLogger.shared.record(
        category: "sync",
        message: "\(kind.displayName) started."
      )
      return
    }

    let finishedAt = event.endDate ?? Date()
    let errorText = detailedErrorDescription(event.error)
    let summary = CloudSyncEventSummary(
      kind: kind,
      succeeded: event.succeeded,
      finishedAt: finishedAt,
      errorDescription: errorText
    )
    lastSyncEvent = summary

    if event.succeeded {
      switch kind {
      case .importFromCloud:
        lastSuccessfulImportAt = finishedAt
      case .exportToCloud:
        lastSuccessfulExportAt = finishedAt
      case .setup, .unknown:
        break
      }
      SyncDebugLogger.shared.record(
        category: "sync",
        message: "\(kind.displayName) succeeded."
      )
    } else {
      lastErrorDescription = errorText ?? "\(kind.displayName) failed without an error description."
      SyncDebugLogger.shared.record(
        category: "sync",
        message: "\(kind.displayName) failed: \(lastErrorDescription ?? "Unknown error")"
      )
    }
  }

  private func map(_ status: CKAccountStatus) -> CloudSyncAccountStatus {
    switch status {
    case .available: return .available
    case .noAccount: return .noAccount
    case .restricted: return .restricted
    case .couldNotDetermine: return .couldNotDetermine
    case .temporarilyUnavailable: return .temporarilyUnavailable
    @unknown default: return .couldNotDetermine
    }
  }

  private func mapEventKind(_ type: NSPersistentCloudKitContainer.EventType) -> CloudSyncEventKind {
    switch type {
    case .setup: return .setup
    case .import: return .importFromCloud
    case .export: return .exportToCloud
    @unknown default: return .unknown
    }
  }

  private func detailedErrorDescription(_ error: Error?) -> String? {
    guard let error else { return nil }
    let nsError = error as NSError
    var parts = [nsError.localizedDescription]
    if nsError.domain == NSCocoaErrorDomain {
      parts.append("CocoaError \(nsError.code)")
    }
    if let ckError = error as? CKError {
      parts.append("CKError \(ckError.code.rawValue)")
    }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
      parts.append("underlying: \(underlying.localizedDescription)")
    }
    return parts.joined(separator: " | ")
  }
}
