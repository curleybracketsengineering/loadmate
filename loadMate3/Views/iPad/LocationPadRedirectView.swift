import SwiftUI

/// Shown if the Locations tab is reached on iPad (tab is normally hidden).
struct LocationPadRedirectView: View {
    var body: some View {
        ContentUnavailableView(
            "Use Load & placement",
            systemImage: "shippingbox",
            description: Text("On iPad, load items and assign zones from the Load & placement tab.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LyneqoTheme.background)
    }
}
