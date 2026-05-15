import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case weight
    case load
    case locations
    case checklist
    case settings
}

struct MainTabView: View {
    @Query private var configs: [SetupConfig]

    @State private var selectedTab: AppTab = .weight
    @State private var showCaravanSetupAlert = false
    @State private var didPresentCaravanSetupPrompt = false

    private var needsCaravanSetup: Bool {
        guard let config = configs.first else { return true }
        return !config.isConfiguredForWeightCalculations
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SummaryView()
                .tag(AppTab.weight)
                .tabItem { Label("Weight", systemImage: "plus.forwardslash.minus") }

            LoadView()
                .tag(AppTab.load)
                .tabItem { Label("Load", systemImage: "shippingbox") }

            LocationView(onNavigateToLoad: { selectedTab = .load })
                .tag(AppTab.locations)
                .tabItem { Label("Locations", systemImage: "mappin.and.ellipse") }

            ChecklistView()
                .tag(AppTab.checklist)
                .tabItem { Label("Checklist", systemImage: "checklist") }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear {
            presentCaravanSetupPromptIfNeeded()
        }
        .onChange(of: needsCaravanSetup) { _, _ in
            presentCaravanSetupPromptIfNeeded()
        }
        .alert("Caravan setup", isPresented: $showCaravanSetupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "Your caravan and tow vehicle details are needed for accurate weight calculations. " +
                "You can still use Load, Locations, and Checklist before completing Settings."
            )
        }
    }

    private func presentCaravanSetupPromptIfNeeded() {
        guard needsCaravanSetup, !didPresentCaravanSetupPrompt else { return }
        didPresentCaravanSetupPrompt = true
        selectedTab = .settings
        showCaravanSetupAlert = true
    }
}
