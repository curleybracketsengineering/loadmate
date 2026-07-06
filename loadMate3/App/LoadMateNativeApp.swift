import SwiftUI
import SwiftData

@main
struct LoadMateNativeApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try LoadMateModelContainer.makeShared()
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
