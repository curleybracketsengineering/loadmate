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

#Preview {
    RootView()
        .modelContainer(for: [
            VehicleProfile.self,
            Trip.self,
            LibraryItem.self,
            LoadedItem.self,
            AppState.self,
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
        ], inMemory: true)
}
