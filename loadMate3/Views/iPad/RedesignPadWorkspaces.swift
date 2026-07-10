import SwiftUI

struct SafetyPadView: View {
    var onNavigateToMaintenance: (() -> Void)?

    var body: some View {
        SafetyView(onNavigateToMaintenance: onNavigateToMaintenance)
            .environment(\.usePadLayout, false)
            .navigationTitle("Safety")
    }
}

enum MaintenancePadTab: String, CaseIterable, Identifiable {
    case maintenance = "Maintenance"
    case tyreSafety = "Tyre safety"

    var id: String { rawValue }
}

struct MaintenancePadView: View {
    @State private var tab: MaintenancePadTab = .maintenance

    var body: some View {
        VStack(spacing: 0) {
            Picker("Maintenance section", selection: $tab) {
                ForEach(MaintenancePadTab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, PadContentLayout.horizontalGutter)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.controlSpacing)
            .frame(maxWidth: PadContentLayout.workspaceMaxWidth)
            .frame(maxWidth: .infinity)

            Group {
                switch tab {
                case .maintenance:
                    MaintenanceView(showsEmbeddedTyrePanel: true)
                        .environment(\.usePadLayout, false)
                case .tyreSafety:
                    TyreSafetyView()
                        .environment(\.usePadLayout, false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(tab.rawValue)
    }
}

struct CarePadView: View {
    var body: some View {
        CareView()
            .environment(\.usePadLayout, false)
            .navigationTitle("Care")
    }
}

struct DocumentsPadView: View {
    var body: some View {
        MaintenanceView()
            .navigationTitle("Documents")
    }
}
