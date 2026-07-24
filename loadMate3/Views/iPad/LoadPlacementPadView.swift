import SwiftUI
import SwiftData

/// iPad landscape workspace: library (load) beside placement cutaway.
struct LoadPlacementPadView: View {
    @State private var showAddItem = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: PadContentLayout.horizontalGutter)

            HStack(alignment: .top, spacing: 0) {
                LoadTabContent(showAddItem: $showAddItem)
                    .frame(width: PadContentLayout.loadColumnWidth)

                Divider()

                PlacementPadPanel()
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: PadContentLayout.workspaceMaxWidth)
            .frame(maxHeight: .infinity)

            Spacer(minLength: PadContentLayout.horizontalGutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LyneqoTheme.background)
    }
}
