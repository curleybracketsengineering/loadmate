import SwiftUI
import SwiftData

struct LoadWorkflowPhoneView: View {
    @Binding var step: LoadWorkflowStep

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var allLoadedItems: [LoadedItem]
    @StateObject private var summaryVM = SummaryViewModel()

    @State private var showAddItem = false
    @State private var showAddTrip = false
    @State private var newTripName = ""
    @State private var tripPendingRename: Trip?
    @State private var tripRenameField = ""

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var activeTrip: Trip? {
        TripStore.activeTrip(for: activeProfile)
    }

    private var profileTrips: [Trip] {
        TripStore.sortedTrips(for: activeProfile)
    }

    private var profileLoadedItems: [LoadedItem] {
        TripStore.loadedItems(for: activeTrip, from: allLoadedItems)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                workflowHeader
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.top, AppScreenMetrics.smallSpacing)
                    .padding(.bottom, AppScreenMetrics.controlSpacing)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .appScreenBackground()
            .navigationTitle("Load")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                workflowFooter
            }
            .task(id: profileLoadedItems.map(\.id)) {
                summaryVM.refresh(profile: activeProfile, trip: activeTrip, loadedItems: profileLoadedItems)
            }
            .sheet(isPresented: $showAddTrip, onDismiss: { newTripName = "" }) {
                AddTripSheet(name: $newTripName) {
                    guard let profile = activeProfile else { return }
                    let trimmed = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    _ = TripStore.addTrip(name: trimmed, to: profile, in: modelContext)
                    newTripName = ""
                    showAddTrip = false
                }
            }
            .alert("Rename trip", isPresented: Binding(
                get: { tripPendingRename != nil },
                set: { if !$0 { tripPendingRename = nil } }
            )) {
                TextField("Trip name", text: $tripRenameField)
                Button("Save") {
                    if let trip = tripPendingRename {
                        TripStore.renameTrip(trip, name: tripRenameField, in: modelContext)
                    }
                    tripPendingRename = nil
                }
                Button("Cancel", role: .cancel) { tripPendingRename = nil }
            }
        }
    }

    @ViewBuilder
    private var workflowHeader: some View {
        VStack(spacing: AppScreenMetrics.controlSpacing) {
            LoadWorkflowStepIndicator(step: $step)

            if let profile = activeProfile, !profileTrips.isEmpty {
                HomeTripSelectorBar(
                    profile: profile,
                    trips: profileTrips,
                    activeTrip: activeTrip,
                    showAddTrip: $showAddTrip,
                    tripPendingRename: $tripPendingRename,
                    tripRenameField: $tripRenameField
                )
            }

            if let profile = activeProfile {
                LoadWorkflowMetricsStrip(
                    profile: profile,
                    caravanSummary: summaryVM.caravanSummary,
                    motorhomeSummary: summaryVM.motorhomeSummary
                )
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .items:
            LoadTabContent(showAddItem: $showAddItem, showsTripPicker: false)
        case .locations:
            LocationView(
                onNavigateToLoad: { step = .items },
                showsTripPicker: false,
                screenTitle: nil
            )
        case .summary:
            ScrollView {
                if let profile = activeProfile {
                    LoadSummaryStepView(
                        profile: profile,
                        trip: activeTrip,
                        caravanSummary: summaryVM.caravanSummary,
                        motorhomeSummary: summaryVM.motorhomeSummary,
                        loadedItems: profileLoadedItems
                    )
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                }
            }
        }
    }

    @ViewBuilder
    private var workflowFooter: some View {
        switch step {
        case .items:
            EmptyView()
        case .locations:
            AppPrimaryButton("View Summary →") { step = .summary }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.vertical, AppScreenMetrics.controlSpacing)
                .background(.bar)
        case .summary:
            EmptyView()
        }
    }
}
