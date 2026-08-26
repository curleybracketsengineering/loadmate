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

  static func isolationStoreDirectory(named name: String) -> URL {
    cloudKitIsolationDirectory.appendingPathComponent(name, isDirectory: true)
  }

  static func isolationStoreURL(named name: String) -> URL {
    isolationStoreDirectory(named: name).appendingPathComponent("\(name).store")
  }

  static var appStateOnlyIsolationStoreURL: URL {
    isolationStoreURL(named: "AppStateOnly")
  }

  static var coreVehicleIsolationStoreURL: URL {
    isolationStoreURL(named: "CoreVehicle")
  }

  static var appStateOnlyIsolationSchema: Schema {
    Schema([AppState.self])
  }

  static var coreVehicleIsolationSchema: Schema {
    Schema([AppState.self, VehicleProfile.self, Trip.self])
  }

  /// Removes only the named diagnostic store. Does not touch the production store or CloudKit.
  static func removeIsolationStoreIfPresent(named name: String) throws {
    let directory = isolationStoreDirectory(named: name)
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }

  static func removeAppStateOnlyIsolationStoreIfPresent() throws {
    try removeIsolationStoreIfPresent(named: "AppStateOnly")
  }

  static func removeCoreVehicleIsolationStoreIfPresent() throws {
    try removeIsolationStoreIfPresent(named: "CoreVehicle")
  }

  static func makeIsolationContainer(named name: String, schema: Schema) throws -> ModelContainer {
    let directory = isolationStoreDirectory(named: name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = ModelConfiguration(
      name,
      schema: schema,
      url: isolationStoreURL(named: name),
      cloudKitDatabase: .private(cloudKitContainerID)
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// CloudKit-backed container containing only `AppState`, in a separate local store file.
  static func makeAppStateOnlyIsolationContainer() throws -> ModelContainer {
    try makeIsolationContainer(named: "AppStateOnly", schema: appStateOnlyIsolationSchema)
  }

  /// CloudKit-backed container containing only AppState, VehicleProfile, and Trip.
  static func makeCoreVehicleIsolationContainer() throws -> ModelContainer {
    try makeIsolationContainer(named: "CoreVehicle", schema: coreVehicleIsolationSchema)
  }
}
