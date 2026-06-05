import SwiftUI
import SwiftData

@main
struct LoadMateNativeApp: App {
    private static let schema = Schema([
        VehicleProfile.self,
        Trip.self,
        LibraryItem.self,
        LoadedItem.self,
        AppState.self,
        ChecklistSection.self,
        ChecklistGroup.self,
        ChecklistItem.self,
    ])

    /// CloudKit-backed store for syncing model changes across iPhone/iPad (when
    /// the app has the required iCloud + Background Remote Notifications capabilities).
    private static let container: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: Self.schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.container)
    }
}
