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
    /// Falls back to a local-only store if CloudKit initialisation fails so settings still persist.
    private static let container: ModelContainer = {
        let cloudConfiguration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: Self.schema, configurations: [cloudConfiguration])
        } catch {
            let localConfiguration = ModelConfiguration(
                schema: Self.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: Self.schema, configurations: [localConfiguration])
            } catch {
                fatalError("Failed to create SwiftData ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.container)
    }
}
