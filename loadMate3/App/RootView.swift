import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @ObservedObject private var errorCenter = AppErrorCenter.shared
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
        .task {
            resolvedState = AppStateStore.ensure(in: modelContext, queried: appStates)
        }
        .onChange(of: appStates.count) { _, _ in
            resolvedState = AppStateStore.ensure(in: modelContext, queried: appStates)
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

#if DEBUG
#Preview("App — Main tabs") {
    MainTabView()
        .previewModelContainer()
}
#endif
