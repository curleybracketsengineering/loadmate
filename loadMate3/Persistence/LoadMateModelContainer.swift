import Foundation
import SwiftData

enum LoadMateModelContainer {
  static let cloudKitContainerID = "iCloud.com.curleybracketsengineering.loadMate3"

  static var schema: Schema {
    Schema([
      VehicleProfile.self,
      Trip.self,
      LibraryItem.self,
      LoadedItem.self,
      MaintenanceRecord.self,
      DocumentRecord.self,
      FaultRecord.self,
      MaintenanceAttachment.self,
      WarrantyPlan.self,
      WarrantyEvent.self,
      TyreRecord.self,
      TyreInspection.self,
      TyrePhoto.self,
      AccidentRecord.self,
      AccidentOtherVehicle.self,
      AccidentWitness.self,
      AccidentPhoto.self,
      AppState.self,
      ChecklistSection.self,
      ChecklistGroup.self,
      ChecklistItem.self,
    ])
  }

  /// Production container with iCloud (CloudKit private database) sync enabled.
  static func makeShared() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      cloudKitDatabase: .private(cloudKitContainerID)
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// In-memory container for SwiftUI previews and unit tests (no CloudKit).
  static func makePreview() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// Dedicated directory for developer CloudKit isolation stores. Never the production SwiftData file.
  static var cloudKitIsolationDirectory: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return appSupport.appendingPathComponent("LoadMateCloudKitIsolation", isDirectory: true)
  }

  static var appStateOnlyIsolationStoreURL: URL {
    cloudKitIsolationDirectory.appendingPathComponent("AppStateOnly.store")
  }

  static var appStateOnlyIsolationSchema: Schema {
    Schema([AppState.self])
  }

  /// Removes only the diagnostic isolation store files. Does not touch the production store or CloudKit.
  static func removeAppStateOnlyIsolationStoreIfPresent() throws {
    let directory = cloudKitIsolationDirectory
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }

  /// CloudKit-backed container containing only `AppState`, in a separate local store file.
  static func makeAppStateOnlyIsolationContainer() throws -> ModelContainer {
    let schema = appStateOnlyIsolationSchema
    try FileManager.default.createDirectory(
      at: cloudKitIsolationDirectory,
      withIntermediateDirectories: true
    )
    let configuration = ModelConfiguration(
      "AppStateIsolation",
      schema: schema,
      url: appStateOnlyIsolationStoreURL,
      cloudKitDatabase: .private(cloudKitContainerID)
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
