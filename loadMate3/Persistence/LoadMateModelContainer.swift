import Foundation
import SwiftData

enum LoadMateModelContainer {
  static let cloudKitContainerID = CloudKitEnvironment.productionContainerID

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

  static var checklistIsolationStoreURL: URL {
    isolationStoreURL(named: "ChecklistModel")
  }

  static var checklistGroupIsolationStoreURL: URL {
    isolationStoreURL(named: "ChecklistGroup")
  }

  static var loadedItemIsolationStoreURL: URL {
    isolationStoreURL(named: "LoadedItem")
  }

  static var libraryItemIsolationStoreURL: URL {
    isolationStoreURL(named: "LibraryItem")
  }

  static var appStateOnlyIsolationSchema: Schema {
    Schema([AppState.self])
  }

  static var coreVehicleIsolationSchema: Schema {
    Schema([AppState.self, VehicleProfile.self, Trip.self])
  }

  /// Diagnostic schema for checklist isolation. Declares the requested models only;
  /// SwiftData still registers relationship destinations such as `ChecklistGroup`.
  static var checklistIsolationSchema: Schema {
    Schema([
      AppState.self,
      VehicleProfile.self,
      Trip.self,
      ChecklistSection.self,
      ChecklistItem.self,
    ])
  }

  static var checklistGroupIsolationSchema: Schema {
    Schema([
      AppState.self,
      VehicleProfile.self,
      Trip.self,
      ChecklistSection.self,
      ChecklistGroup.self,
      ChecklistItem.self,
    ])
  }

  static var loadedItemIsolationSchema: Schema {
    Schema([
      AppState.self,
      VehicleProfile.self,
      Trip.self,
      LibraryItem.self,
      LoadedItem.self,
    ])
  }

  static var libraryItemIsolationSchema: Schema {
    Schema([
      AppState.self,
      VehicleProfile.self,
      LibraryItem.self,
    ])
  }

  static func requestedAndRegisteredModelLines(requested: [String], schema: Schema) -> [String] {
    let registered = Set(schema.entities.compactMap(\.name))
    let extra = registered.subtracting(requested).sorted()
    var lines = ["  Requested: \(requested.joined(separator: ", "))"]
    if extra.isEmpty {
      lines.append("  Also registered: none")
    } else {
      lines.append("  Also registered: \(extra.joined(separator: ", "))")
    }
    return lines
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

  static func removeChecklistIsolationStoreIfPresent() throws {
    try removeIsolationStoreIfPresent(named: "ChecklistModel")
  }

  static func removeChecklistGroupIsolationStoreIfPresent() throws {
    try removeIsolationStoreIfPresent(named: "ChecklistGroup")
  }

  static func removeLoadedItemIsolationStoreIfPresent() throws {
    try removeIsolationStoreIfPresent(named: "LoadedItem")
  }

  static func removeLibraryItemIsolationStoreIfPresent() throws {
    try removeIsolationStoreIfPresent(named: "LibraryItem")
  }

  static func makeIsolationContainer(named name: String, schema: Schema) throws -> ModelContainer {
    let directory = isolationStoreDirectory(named: name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = ModelConfiguration(
      name,
      schema: schema,
      url: isolationStoreURL(named: name),
      cloudKitDatabase: .private(CloudKitEnvironment.diagnosticContainerID)
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

  /// CloudKit-backed container for checklist isolation. Separate local store from production and core vehicle.
  static func makeChecklistIsolationContainer() throws -> ModelContainer {
    try makeIsolationContainer(named: "ChecklistModel", schema: checklistIsolationSchema)
  }

  static func makeChecklistGroupIsolationContainer() throws -> ModelContainer {
    try makeIsolationContainer(named: "ChecklistGroup", schema: checklistGroupIsolationSchema)
  }

  static func makeLoadedItemIsolationContainer() throws -> ModelContainer {
    try makeIsolationContainer(named: "LoadedItem", schema: loadedItemIsolationSchema)
  }

  static func makeLibraryItemIsolationContainer() throws -> ModelContainer {
    try makeIsolationContainer(named: "LibraryItem", schema: libraryItemIsolationSchema)
  }
}
