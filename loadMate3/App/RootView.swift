import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @StateObject private var disclaimerVM = DisclaimerViewModel()
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

#if DEBUG
#Preview("App Preview") {
    RootView()
        .previewModelContainer()
}
#endif
