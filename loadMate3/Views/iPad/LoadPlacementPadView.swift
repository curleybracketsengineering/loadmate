import SwiftUI
import SwiftData

/// iPad landscape workspace: library (load) beside placement cutaway.
struct LoadPlacementPadView: View {
    @State private var showAddItem = false

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 0) {
                LoadTabContent(showAddItem: $showAddItem)
                    .frame(minWidth: 360, idealWidth: 400, maxWidth: 440)

                Divider()

                PlacementPadPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .appPrincipalTabTitle("Load & placement")
        }
    }
}
