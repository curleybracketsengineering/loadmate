import SwiftUI

struct MoreView: View {
    var onNavigateToHome: (() -> Void)?

    var body: some View {
        NavigationStack {
            SettingsView(onNavigateToSummary: onNavigateToHome)
        }
    }
}
