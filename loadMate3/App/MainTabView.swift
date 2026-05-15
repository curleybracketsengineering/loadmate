import SwiftUI

enum AppTab: Hashable {
    case weight
    case load
    case locations
    case checklist
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .weight

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
    }
}
