import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @StateObject private var disclaimerVM = DisclaimerViewModel()
    @State private var resolvedState: AppState?

    var body: some View {
        Group {
            if let state = resolvedState {
                if state.disclaimerAccepted {
                    MainTabView()
                } else {
                    DisclaimerView(appState: state)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task(id: appStates.count) {
            resolvedState = disclaimerVM.ensureAppState(in: modelContext, existing: appStates.first)
        }
    }
}

#Preview("App Preview") {
    RootView()
        .modelContainer(RootPreviewData.makeContainer())
}

private enum RootPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            SetupConfig.self,
            LibraryItem.self,
            LoadedItem.self,
            AppState.self,
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext

            let appState = AppState(disclaimerAccepted: true, acceptedAt: .now)
            context.insert(appState)

            let config = SetupConfig(baseWeightKg: 1250, weighbridgeWeightKg: 1285, mtplmKg: 1500, carMaxTowBallKg: 75)
            context.insert(config)

            let chair = LibraryItem(name: "Camping Chair", weightKg: 4.5, defaultZoneRaw: LoadZone.middle.rawValue)
            let awning = LibraryItem(name: "Awning", weightKg: 22, defaultZoneRaw: LoadZone.front.rawValue)
            context.insert(chair)
            context.insert(awning)

            context.insert(LoadedItem(item: chair, quantity: 1, zone: .middle, loadedAt: .now.addingTimeInterval(-60)))
            context.insert(LoadedItem(item: chair, quantity: 1, zone: .rear, loadedAt: .now))
            context.insert(LoadedItem(item: awning, quantity: 1, zone: .front))

            try context.save()
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
