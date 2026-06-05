#if DEBUG
import SwiftData
import SwiftUI

/// SwiftUI preview fixtures: production vehicle bootstrap, demo load items, disclaimer accepted.
enum PreviewSupport {
    @MainActor
    static func seedIfEmpty(in context: ModelContext) throws {
        let profiles = try context.fetch(FetchDescriptor<VehicleProfile>())
        var appStateDescriptor = FetchDescriptor<AppState>()
        appStateDescriptor.fetchLimit = 1
        let existingAppState = try context.fetch(appStateDescriptor).first

        let boot = VehicleProfileStore.ensureInitialData(
            in: context,
            profiles: profiles,
            appState: existingAppState
        )

        if !boot.appState.disclaimerAccepted {
            boot.appState.disclaimerAccepted = true
            boot.appState.acceptedAt = .now
        }

        let loadedItems = try context.fetch(FetchDescriptor<LoadedItem>())
        if loadedItems.isEmpty,
           let caravan = boot.profiles.first(where: { $0.kind == .caravan }) {
            let trip = TripStore.activeTrip(for: caravan)
                ?? TripStore.ensureDefaultTrip(for: caravan, in: context)
            let libraryItems = try context.fetch(FetchDescriptor<LibraryItem>())
            let loadViewModel = LoadViewModel()
            _ = loadViewModel.applyCaravanStarterKit(
                trip: trip,
                libraryItems: libraryItems,
                loadedItems: loadedItems,
                in: context
            )
        }

        try context.save()
    }
}

/// Seeds preview data after SwiftUI attaches an in-memory model container.
private struct PreviewSeedModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var didSeed = false
    @State private var seedError: String?

    func body(content: Content) -> some View {
        content
            .task {
                guard !didSeed else { return }
                didSeed = true
                do {
                    try PreviewSupport.seedIfEmpty(in: modelContext)
                } catch {
                    seedError = error.localizedDescription
                }
            }
            .alert("Preview seed failed", isPresented: Binding(
                get: { seedError != nil },
                set: { if !$0 { seedError = nil } }
            )) {
                Button("OK", role: .cancel) { seedError = nil }
            } message: {
                Text(seedError ?? "")
            }
    }
}

extension View {
    /// In-memory SwiftData store configured for Xcode previews.
    func previewModelContainer() -> some View {
        modelContainer(
            for: [
                VehicleProfile.self,
                Trip.self,
                LibraryItem.self,
                LoadedItem.self,
                AppState.self,
                ChecklistSection.self,
                ChecklistGroup.self,
                ChecklistItem.self,
            ],
            inMemory: true
        )
        .modifier(PreviewSeedModifier())
    }
}
#endif
