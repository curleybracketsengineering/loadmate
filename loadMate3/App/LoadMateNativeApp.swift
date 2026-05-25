import SwiftUI
import SwiftData

@main
struct LoadMateNativeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            VehicleProfile.self,
            Trip.self,
            LibraryItem.self,
            LoadedItem.self,
            AppState.self,
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
        ])
    }
}
