import SwiftUI
import SwiftData

@main
struct LoadMateNativeApp: App {
    @UIApplicationDelegateAdaptor(LoadMateAppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer = {
        do {
            return try LoadMateModelContainer.makeShared()
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }()

    @ObservedObject private var cloudSync = CloudSyncMonitor.shared
    private let vehicleLookup: any VehicleLookupProviding = VehicleLookupService.makeLive()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(cloudSync)
                .environment(\.vehicleLookup, vehicleLookup)
                .tint(LyneqoTheme.primaryTeal)
        }
        .modelContainer(modelContainer)
    }
}
