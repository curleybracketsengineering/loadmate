import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem { Label("Summary", systemImage: "gauge.with.dots.needle.67percent") }

            LoadView()
                .tabItem { Label("Load", systemImage: "shippingbox") }

            LocationView()
                .tabItem { Label("Location", systemImage: "mappin.and.ellipse") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
