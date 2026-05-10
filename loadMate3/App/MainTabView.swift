import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem { Label("Weight", systemImage: "plus.forwardslash.minus") }

            LoadView()
                .tabItem { Label("Load", systemImage: "shippingbox") }

            LocationView()
                .tabItem { Label("Locations", systemImage: "mappin.and.ellipse") }

            ChecklistView()
                .tabItem { Label("Checklist", systemImage: "checklist") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
