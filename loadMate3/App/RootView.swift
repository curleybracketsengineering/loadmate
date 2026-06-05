import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @StateObject private var disclaimerVM = DisclaimerViewModel()
    @StateObject private var errorCenter = AppErrorCenter.shared
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
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { errorCenter.message != nil },
                set: { if !$0 { errorCenter.clear() } }
            ),
            presenting: errorCenter.message
        ) { _ in
            Button("OK", role: .cancel) { errorCenter.clear() }
        } message: { message in
            Text(message)
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
            VehicleProfile.self,
            Trip.self,
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

            let profile = VehicleProfile(name: "Preview Caravan", kind: .caravan, sortOrder: 0)
            profile.baseWeightKg = 1250
            profile.weighbridgeWeightKg = 1285
            profile.mtplmKg = 1500
            profile.carMaxTowBallKg = 75
            context.insert(profile)
            appState.activeProfileID = profile.id

            let trip = Trip(name: "Weekend", sortOrder: 0, profile: profile)
            context.insert(trip)
            profile.activeTripID = trip.id

            let chair = LibraryItem(name: "Camping Chair", weightKg: 4.5, defaultZoneRaw: LoadZone.middle.rawValue)
            let awning = LibraryItem(name: "Awning", weightKg: 22, defaultZoneRaw: LoadZone.front.rawValue)
            context.insert(chair)
            context.insert(awning)

            context.insert(LoadedItem(item: chair, quantity: 1, zone: .middle, trip: trip))
            context.insert(LoadedItem(item: awning, quantity: 1, zone: .front, trip: trip))

            try context.save()
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
