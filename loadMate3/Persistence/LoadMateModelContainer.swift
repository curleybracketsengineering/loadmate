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
}
