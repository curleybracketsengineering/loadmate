import SwiftUI
import SwiftData

@main
struct LoadMateNativeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            SetupConfig.self,
            LibraryItem.self,
            LoadedItem.self,
            AppState.self,
            ChecklistSection.self,
            ChecklistItem.self,
        ])
    }
}

