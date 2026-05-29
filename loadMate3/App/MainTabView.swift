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
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @State private var selectedTab: AppTab = .weight
    @State private var showSetupAlert = false
    @State private var didPresentSetupPrompt = false

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: appStates.first)
    }

    private var needsSetup: Bool {
        guard let profile = activeProfile else { return true }
        return !profile.isConfiguredForWeightCalculations
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SummaryView()
                .tag(AppTab.weight)
                .tabItem { Label("Weight", systemImage: "plus.forwardslash.minus") }

            LoadView()
                .tag(AppTab.load)
                .tabItem {
                    Label(
                        AppLayout.usePadLayout ? "Load & placement" : "Load",
                        systemImage: "shippingbox"
                    )
                }

            if !AppLayout.usePadLayout {
                LocationView(onNavigateToLoad: { selectedTab = .load })
                    .tag(AppTab.locations)
                    .tabItem { Label("Locations", systemImage: "mappin.and.ellipse") }
            }

            ChecklistView()
                .tag(AppTab.checklist)
                .tabItem { Label("Checklist", systemImage: "checklist") }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear {
            presentSetupPromptIfNeeded()
        }
        .onChange(of: needsSetup) { _, _ in
            presentSetupPromptIfNeeded()
        }
        .alert(setupAlertTitle, isPresented: $showSetupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(setupAlertMessage)
        }
    }

    private var setupAlertTitle: String {
        activeProfile?.kind == .motorhome ? "Motorhome setup" : "Caravan setup"
    }

    private var setupAlertMessage: String {
        guard let profile = activeProfile else {
            return "Add a vehicle in Settings for weight calculations. You can still use Load, Locations, and Checklist first."
        }
        switch profile.kind {
        case .caravan:
            return "Your caravan and tow vehicle details are needed for accurate weight calculations. You can still use Load, Locations, and Checklist before completing Settings."
        case .motorhome:
            return "Your motorhome MAM and axle limits are needed for accurate weight estimates. Enter weighbridge axle weights when you can. You can still use Load, Locations, and Checklist before completing Settings."
        }
    }

    private func presentSetupPromptIfNeeded() {
        guard needsSetup, !didPresentSetupPrompt else { return }
        didPresentSetupPrompt = true
        selectedTab = .settings
        showSetupAlert = true
    }
}
