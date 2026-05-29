import SwiftUI
import SwiftData

/// iPad landscape weight summary — horizontal layout using the same calculations as iPhone.
struct SummaryPadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var allLoadedItems: [LoadedItem]
    @StateObject private var viewModel = SummaryViewModel()

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: appStates.first)
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
            "\(profile.id)-\(profile.kindRaw)-\(profile.baseWeightKg)-\(profile.weighbridgeWeightKg)-\(profile.mtplmKg)-\(profile.maxFrontAxleKg)-\(profile.maxRearAxleKg)-\(profile.maxGarageKg)-\(profile.garageLimitIncludesBikeRack)-\(profile.usesManualTowBarLoad)-\(profile.maxTowBarKg)-\(profile.weighbridgeFrontAxleKg)-\(profile.weighbridgeRearAxleKg)"
        } ?? "no-profile"
        let itemSignature = profileLoadedItems.map {
            "\($0.id.uuidString)-\($0.quantity)-\($0.zoneRaw)-\($0.item?.weightKg ?? 0)"
        }.joined(separator: "|")
        return "\(tripSignature)|\(profileSignature)|\(itemSignature)"
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
            .task(id: refreshToken) {
                viewModel.refresh(profile: activeProfile, trip: activeTrip, loadedItems: profileLoadedItems)
            }
            .task(id: profiles.map(\.id)) {
                TripStore.ensureTripsMigrated(in: modelContext, profiles: profiles)
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
                    if let summary = viewModel.caravanSummary {
                        SummaryPadCaravanLayout(summary: summary, profile: profile)
                    }
                case .motorhome:
                    if let summary = viewModel.motorhomeSummary {
                        SummaryPadMotorhomeLayout(summary: summary, profile: profile)
                    }
                }
            }
            .padding(AppScreenMetrics.horizontalPadding)
            .padding(.vertical, AppScreenMetrics.verticalScreenPadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Caravan (iPad)

private struct SummaryPadCaravanLayout: View {
    let summary: WeightSummary
    let profile: VehicleProfile

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            SummaryPadStatusBanner.caravan(summary: summary, profile: profile)

            HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
                SummaryPadCaravanWeightCard(summary: summary, profile: profile)
                    .frame(maxWidth: .infinity)
                SummaryPadCaravanNoseCard(summary: summary, profile: profile)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Motorhome (iPad)

private struct SummaryPadMotorhomeLayout: View {
    let summary: MotorhomeWeightSummary
    let profile: VehicleProfile

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            SummaryPadStatusBanner.motorhome(summary: summary, profile: profile)

            HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
                MotorhomeSummaryContent.grossWeightCard(summary: summary, profile: profile)
                    .frame(maxWidth: .infinity)

                VStack(spacing: AppScreenMetrics.sectionSpacing) {
                    MotorhomeSummaryContent.axleCard(
                        title: "Front Axle",
                        estimatedKg: summary.estimatedFrontAxleKg,
                        limitKg: profile.maxFrontAxleKg,
                        impactKg: summary.frontAxleImpactKg,
                        fillFraction: CGFloat(summary.frontAxleFillFraction(profile: profile)),
                        isOverLimit: summary.isOverFrontAxle,
                        accessibilityLabel: "Progress toward front axle limit"
                    )
                    MotorhomeSummaryContent.axleCard(
                        title: "Rear Axle",
                        estimatedKg: summary.estimatedRearAxleKg,
                        limitKg: profile.maxRearAxleKg,
                        impactKg: summary.rearAxleImpactKg,
                        fillFraction: CGFloat(summary.rearAxleFillFraction(profile: profile)),
                        isOverLimit: summary.isOverRearAxle,
                        accessibilityLabel: "Progress toward rear axle limit"
                    )
                }
                .frame(maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
                if profile.monitorsGarageLimit {
                    MotorhomeSummaryContent.garageCard(summary: summary, profile: profile)
                        .frame(maxWidth: .infinity)
                }
                if summary.monitorsTowBar {
                    MotorhomeSummaryContent.towBarCard(summary: summary, profile: profile)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Shared pad chrome

private enum SummaryPadStatusBanner {
    @ViewBuilder
    static func caravan(summary: WeightSummary, profile: VehicleProfile) -> some View {
        if summary.isOverallSafe {
            padSafeBanner
        } else if summary.isOverMTPLM {
            padWarningBanner(title: "Gross weight limit exceeded", color: AppColors.red)
        } else if summary.isOverTowBallLimit {
            padWarningBanner(title: "Tow ball limit exceeded", color: AppColors.red)
        } else {
            padWarningBanner(title: "Check nose weight", color: AppColors.orange)
        }
    }

    @ViewBuilder
    static func motorhome(summary: MotorhomeWeightSummary, profile: VehicleProfile) -> some View {
        if summary.isOverallSafe {
            padSafeBanner
        } else if summary.isOverMAM {
            padWarningBanner(title: "Gross weight limit exceeded", color: AppColors.red)
        } else if summary.isOverFrontAxle {
            padWarningBanner(title: "Front axle limit exceeded", color: AppColors.red)
        } else if summary.isOverRearAxle {
            padWarningBanner(title: "Rear axle limit exceeded", color: AppColors.red)
        } else {
            padWarningBanner(title: "Check axle and tow bar loads", color: AppColors.orange)
        }
    }

    private static var padSafeBanner: some View {
        Text("SAFE")
            .font(.title2.weight(.bold))
            .foregroundStyle(Color.white)
            .tracking(1.5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private static func padWarningBanner(title: String, color: Color) -> some View {
        HStack(spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color.white)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
            Spacer(minLength: 0)
        }
        .padding(AppScreenMetrics.fieldSpacing)
        .frame(maxWidth: .infinity)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }
}

private struct SummaryPadCaravanWeightCard: View {
    let summary: WeightSummary
    let profile: VehicleProfile

    var body: some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Current Weight")
                    .font(.headline)
                Text(Formatters.kg(summary.totalWeightKg))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(summary.isOverMTPLM ? AppColors.red : Color.accentColor)
                padProgressBar(
                    fill: CGFloat(summary.mtplmFillFraction(profile: profile)),
                    isOverLimit: summary.isOverMTPLM
                )
                Text("MTPLM \(Formatters.kg(profile.mtplmKg)) · Available \(Formatters.kg(summary.availableWeightKg))")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

private struct SummaryPadCaravanNoseCard: View {
    let summary: WeightSummary
    let profile: VehicleProfile

    var body: some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Nose Weight")
                    .font(.headline)
                let zoneBounds = summary.noseGaugeZoneBounds(profile: profile)
                NoseWeightSafeZoneGauge(
                    zoneLowKg: zoneBounds.low,
                    zoneHighKg: zoneBounds.high,
                    carMaxTowBallKg: profile.effectiveMaxTowBallKg,
                    estimatedNoseKg: summary.estimatedNoseWeightKg
                )
                Text("Estimated \(Formatters.kg(summary.estimatedNoseWeightKg))")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(summary.isOverTowBallLimit ? AppColors.red : Color.accentColor)
            }
        }
    }
}

private func padProgressBar(fill: CGFloat, isOverLimit: Bool) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(Color(.tertiarySystemFill))
            Capsule()
                .fill(isOverLimit ? AppColors.red : Color.accentColor)
                .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
        }
    }
    .frame(height: 10)
}
