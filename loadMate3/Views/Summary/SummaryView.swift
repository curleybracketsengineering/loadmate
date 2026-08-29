import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var allLoadedItems: [LoadedItem]
    @StateObject private var viewModel = SummaryViewModel()
    @State private var tripPendingRename: Trip?
    @State private var tripRenameField = ""

    var onNavigateToLocations: (() -> Void)?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var activeTrip: Trip? {
        TripStore.activeTrip(for: activeProfile)
    }

    private var profileLoadedItems: [LoadedItem] {
        TripStore.loadedItems(for: activeTrip, from: allLoadedItems)
    }

    private var refreshToken: String {
        let tripSignature = activeTrip.map { "\($0.id)-\($0.name)-\($0.manualTowBarLoadKg)" } ?? "no-trip"
        let profileSignature = activeProfile.map { profile in
            "\(profile.id)-\(profile.kindRaw)-\(profile.baseWeightKg)-\(profile.weighbridgeWeightKg)-\(profile.mtplmKg)-\(profile.maxFrontAxleKg)-\(profile.maxRearAxleKg)-\(profile.maxGarageKg)-\(profile.garageLimitIncludesBikeRack)-\(profile.hasBikeRack)-\(profile.usesManualTowBarLoad)-\(profile.maxTowBarKg)-\(profile.weighbridgeFrontAxleKg)-\(profile.weighbridgeRearAxleKg)"
        } ?? "no-profile"

        let itemSignature = profileLoadedItems.map {
            "\($0.id.uuidString)-\($0.quantity)-\($0.zoneRaw)-\($0.item?.weightKg ?? 0)"
        }.joined(separator: "|")

        return "\(tripSignature)|\(profileSignature)|\(itemSignature)"
    }

    var body: some View {
        if usePadLayout {
            SummaryPadView()
        } else {
            phoneBody
        }
    }

    private var phoneBody: some View {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LyneqoTheme.background)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: refreshToken) {
                viewModel.refresh(profile: activeProfile, trip: activeTrip, loadedItems: profileLoadedItems)
            }
            .task(id: profiles.map(\.id)) {
                TripStore.ensureTripsMigrated(in: modelContext, profiles: profiles)
            }
            .alert("Rename Loading Configuration", isPresented: Binding(
                get: { tripPendingRename != nil },
                set: { if !$0 { tripPendingRename = nil } }
            )) {
                TextField("Loading configuration name", text: $tripRenameField)
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
            return "Can't show summary information until you add a vehicle profile in Settings."
        }
        return profile.weightCalculationSetupSummaryMessage
    }

    @ViewBuilder
    private func configuredContent(profile: VehicleProfile) -> some View {
        ScrollView {
            VStack(spacing: AppScreenMetrics.sectionSpacing) {
                switch profile.kind {
                case .caravan:
                    if let summary = viewModel.caravanSummary {
                        CaravanSummaryPhoneLayout(
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
                    if let summary = viewModel.motorhomeSummary {
                        MotorhomeSummaryPhoneLayout(
                            profile: profile,
                            trip: activeTrip,
                            summary: summary,
                            loadedItems: profileLoadedItems,
                            onRenameTrip: {
                                guard let trip = activeTrip else { return }
                                tripPendingRename = trip
                                tripRenameField = trip.name
                            },
                            onNavigateToLocations: onNavigateToLocations
                        )
                    }
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(LyneqoTheme.background)
    }

}
