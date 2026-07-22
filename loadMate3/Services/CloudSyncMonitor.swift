import CloudKit
import Combine
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

@MainActor
final class CloudSyncMonitor: ObservableObject {
  @Published private(set) var accountStatus: CloudSyncAccountStatus = .couldNotDetermine
  @Published private(set) var lastCheckedAt: Date?
  @Published private(set) var lastErrorDescription: String?

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
}
