import SwiftUI
import SwiftData

/// iPad landscape weight summary — horizontal layout using the same calculations as iPhone.
struct SummaryPadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var allLoadedItems: [LoadedItem]
    @State private var tripPendingRename: Trip?
    @State private var tripRenameField = ""

    private var active: ActiveLoadContext {
        ActiveLoadContext(
            profiles: profiles,
            modelContext: modelContext,
            appStates: appStates,
            allLoadedItems: allLoadedItems
        )
    }

    private var activeProfile: VehicleProfile? { active.profile }
    private var activeTrip: Trip? { active.trip }
    private var profileLoadedItems: [LoadedItem] { active.loadedItems }

    // Derived inline so SwiftData observation recomputes on any input change (see SummaryView).
    private var caravanSummary: WeightSummary? {
        guard let profile = activeProfile, profile.kind == .caravan else { return nil }
        return WeightCalculator.summary(profile: profile, loadedItems: profileLoadedItems)
    }

    private var motorhomeSummary: MotorhomeWeightSummary? {
        guard let profile = activeProfile, profile.kind == .motorhome else { return nil }
        return MotorhomeWeightCalculator.summary(profile: profile, loadedItems: profileLoadedItems, trip: activeTrip)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = activeProfile, profile.isConfiguredForWeightCalculations {
                    configuredContent(profile: profile)
                } else {
                    ContentUnavailableView(
                        "Setup required",
                        systemImage: "exclamationmark.triangle",
                        description: Text(setupRequiredMessage)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .task(id: profiles.map(\.id)) {
                TripStore.ensureTripsMigrated(in: modelContext, profiles: profiles)
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

    private var setupRequiredMessage: String {
        guard let profile = activeProfile else {
            return "Open Settings and add a vehicle profile."
        }
        switch profile.kind {
        case .caravan:
            return "Open Settings and enter base weight, MTPLM, and tow-ball limit."
        case .motorhome:
            return "Open Settings and enter base weight, MAM, and front and rear axle limits."
        }
    }

    @ViewBuilder
    private func configuredContent(profile: VehicleProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                switch profile.kind {
                case .caravan:
                    if let summary = caravanSummary {
                        CaravanSummaryPadLayout(
                            profile: profile,
                            trip: activeTrip,
                            summary: summary,
                            loadedItems: profileLoadedItems,
                            onRenameTrip: {
                                guard let trip = activeTrip else { return }
                                tripPendingRename = trip
                                tripRenameField = trip.name
                            }
                        )
                    }
                case .motorhome:
                    if let summary = motorhomeSummary {
                        MotorhomeSummaryPadLayout(
                            profile: profile,
                            trip: activeTrip,
                            summary: summary,
                            loadedItems: profileLoadedItems,
                            onRenameTrip: {
                                guard let trip = activeTrip else { return }
                                tripPendingRename = trip
                                tripRenameField = trip.name
                            }
                        )
                    }
                }
            }
            .padding(AppScreenMetrics.horizontalPadding)
            .padding(.vertical, AppScreenMetrics.verticalScreenPadding)
            .frame(maxWidth: .infinity)
            .padReadableContent(maxWidth: PadContentLayout.workspaceMaxWidth)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
