import CloudKit
import Combine
import CoreData
import Foundation

#if canImport(UIKit)
import UIKit
#endif

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
      return "Your vehicles, trips, load lists, checklists, and photos stay up to date across your iPhone and iPad signed into the same Apple ID."
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
  static let shared = CloudSyncMonitor()

  @Published private(set) var accountStatus: CloudSyncAccountStatus = .couldNotDetermine
  @Published private(set) var lastCheckedAt: Date?
  @Published private(set) var lastErrorDescription: String?
  @Published private(set) var lastSyncEvent: CloudSyncEventSummary?
  @Published private(set) var lastSuccessfulImportAt: Date?
  @Published private(set) var lastSuccessfulExportAt: Date?
  @Published private(set) var isObservingSyncEvents = false
  @Published private(set) var isRegisteredForRemoteNotifications = false
  @Published private(set) var pushRegistrationDetail = "Waiting for APNs registration…"
  @Published private(set) var cloudKitSchemaDetail = "Not checked yet"

  private var accountObserver: NSObjectProtocol?
  private var syncEventObserver: NSObjectProtocol?
  private var didStart = false

  private init() {
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
    refreshPushRegistrationStatus()
    Task { await refresh() }
  }

  func refresh() async {
    refreshPushRegistrationStatus()
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

  func refreshPushRegistrationStatus() {
    #if canImport(UIKit)
    let registered = UIApplication.shared.isRegisteredForRemoteNotifications
    isRegisteredForRemoteNotifications = registered
    if registered, pushRegistrationDetail.hasPrefix("Waiting") {
      pushRegistrationDetail = "Registered for remote notifications."
    } else if !registered, pushRegistrationDetail.hasPrefix("Waiting") {
      pushRegistrationDetail =
        "Not registered yet (on Simulator this is often inconclusive; on a real device check the push entitlement)."
    }
    #else
    isRegisteredForRemoteNotifications = false
    pushRegistrationDetail = "UIKit unavailable."
    #endif
  }

  func handlePushRegistrationSuccess(deviceTokenByteCount: Int) {
    isRegisteredForRemoteNotifications = true
    pushRegistrationDetail = "Registered for remote notifications (\(deviceTokenByteCount) byte token)."
    SyncDebugLogger.shared.record(
      category: "push",
      message: "Registered for remote notifications (\(deviceTokenByteCount) byte token)."
    )
  }

  func handlePushRegistrationFailure(_ error: Error) {
    isRegisteredForRemoteNotifications = false
    pushRegistrationDetail = "Push registration failed: \(error.localizedDescription)"
    lastErrorDescription = pushRegistrationDetail
    SyncDebugLogger.shared.record(
      category: "push",
      message: "Push registration failed: \(error.localizedDescription)"
    )
  }

  /// Asks CloudKit whether the Core Data zone and `CD_AppState` record type exist in this build's environment.
  func probeCloudKitSchema() async {
    let container = CKContainer(identifier: LoadMateModelContainer.cloudKitContainerID)
    let database = container.privateCloudDatabase
    let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")

    SyncDebugLogger.shared.record(category: "schema", message: "Probing CloudKit schema…")

    do {
      let zones = try await database.allRecordZones()
      let hasCoreDataZone = zones.contains { $0.zoneID.zoneName == zoneID.zoneName }

      guard hasCoreDataZone else {
        cloudKitSchemaDetail =
          "No Core Data CloudKit zone yet. Schema may be fine but nothing has mirrored — or this environment is empty."
        SyncDebugLogger.shared.record(category: "schema", message: cloudKitSchemaDetail)
        return
      }

      let query = CKQuery(recordType: "CD_AppState", predicate: NSPredicate(value: true))
      let (matchResults, _) = try await database.records(matching: query, inZoneWith: zoneID)
      let recordCount = matchResults.reduce(into: 0) { count, pair in
        if case .success = pair.1 { count += 1 }
      }
      cloudKitSchemaDetail =
        "Schema OK — CD_AppState reachable in this environment (\(recordCount) record\(recordCount == 1 ? "" : "s"))."
      SyncDebugLogger.shared.record(category: "schema", message: cloudKitSchemaDetail)
    } catch let error as CKError where error.code == .unknownItem {
      cloudKitSchemaDetail =
        "Schema missing — CD_AppState unknown here. For TestFlight/App Store, deploy the Development schema to Production in CloudKit Console."
      lastErrorDescription = cloudKitSchemaDetail
      SyncDebugLogger.shared.record(category: "schema", message: cloudKitSchemaDetail)
    } catch let error as CKError where error.code == .notAuthenticated {
      cloudKitSchemaDetail = "Cannot probe schema — sign in to iCloud on this device."
      SyncDebugLogger.shared.record(category: "schema", message: cloudKitSchemaDetail)
    } catch {
      if CloudSyncErrorFormatting.isMissingQueryableIndex(error) {
        cloudKitSchemaDetail =
          "Indexes missing — in CloudKit Console mark recordName as Queryable on each CD_* type (Development), then Deploy Schema to Production."
      } else {
        cloudKitSchemaDetail = "Schema probe failed: \(CloudSyncErrorFormatting.description(for: error))"
      }
      lastErrorDescription = cloudKitSchemaDetail
      SyncDebugLogger.shared.record(category: "schema", message: cloudKitSchemaDetail)
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

      Task { @MainActor [weak self] in
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
    return CloudSyncErrorFormatting.description(for: error)
  }
}

enum CloudSyncErrorFormatting {
  static func description(for error: Error) -> String {
    flatten(error).joined(separator: " | ")
  }

  static func isMissingQueryableIndex(_ error: Error) -> Bool {
    flatten(error).contains { $0.localizedCaseInsensitiveContains("not marked queryable") }
  }

  static func flatten(_ error: Error, depth: Int = 0) -> [String] {
    guard depth < 6 else { return [] }
    let nsError = error as NSError
    var parts = [headline(nsError)]
    var seen = Set<String>()

    for inner in nestedErrors(in: nsError) {
      let innerNS = inner as NSError
      let key = "\(innerNS.domain):\(innerNS.code):\(innerNS.localizedDescription)"
      guard seen.insert(key).inserted else { continue }
      parts.append(contentsOf: flatten(inner, depth: depth + 1))
    }
    return parts
  }

  private static func headline(_ nsError: NSError) -> String {
    if nsError.domain == CKErrorDomain {
      let code = CKError.Code(rawValue: nsError.code)
      return "CKError \(nsError.code) (\(ckCodeName(code))): \(nsError.localizedDescription)"
    }
    if nsError.domain == NSCocoaErrorDomain {
      return "\(nsError.localizedDescription) [CocoaError \(nsError.code)]"
    }
    return "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
  }

  private static func nestedErrors(in nsError: NSError) -> [Error] {
    var nested: [Error] = []
    if let ckError = nsError as? CKError, let partial = ckError.partialErrorsByItemID {
      nested.append(contentsOf: partial.values)
    }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
      nested.append(underlying)
    }
    if let detailed = nsError.userInfo[NSDetailedErrorsKey] as? [Error] {
      nested.append(contentsOf: detailed)
    }
    for value in nsError.userInfo.values {
      if let map = value as? [AnyHashable: NSError] {
        nested.append(contentsOf: Array(map.values))
      }
    }
    return nested
  }

  private static func ckCodeName(_ code: CKError.Code?) -> String {
    switch code {
    case .internalError: return "internalError"
    case .partialFailure: return "partialFailure"
    case .networkUnavailable: return "networkUnavailable"
    case .networkFailure: return "networkFailure"
    case .badContainer: return "badContainer"
    case .serviceUnavailable: return "serviceUnavailable"
    case .requestRateLimited: return "requestRateLimited"
    case .missingEntitlement: return "missingEntitlement"
    case .notAuthenticated: return "notAuthenticated"
    case .permissionFailure: return "permissionFailure"
    case .unknownItem: return "unknownItem"
    case .invalidArguments: return "invalidArguments"
    case .serverRecordChanged: return "serverRecordChanged"
    case .serverRejectedRequest: return "serverRejectedRequest"
    case .assetFileNotFound: return "assetFileNotFound"
    case .quotaExceeded: return "quotaExceeded"
    case .zoneNotFound: return "zoneNotFound"
    case .changeTokenExpired: return "changeTokenExpired"
    case .limitExceeded: return "limitExceeded"
    case .userDeletedZone: return "userDeletedZone"
    case .serverResponseLost: return "serverResponseLost"
    case .assetNotAvailable: return "assetNotAvailable"
    case .accountTemporarilyUnavailable: return "accountTemporarilyUnavailable"
    case .none: return "unknown"
    @unknown default: return "other"
    }
  }
}
