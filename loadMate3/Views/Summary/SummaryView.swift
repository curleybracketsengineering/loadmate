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
                    .background(Color(.systemGroupedBackground))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: refreshToken) {
                viewModel.refresh(profile: activeProfile, trip: activeTrip, loadedItems: profileLoadedItems)
            }
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
                        caravanStatusBanner(summary: summary, profile: profile)
                        caravanCurrentWeightCard(summary: summary, profile: profile)
                        caravanNoseWeightCard(summary: summary, profile: profile)
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
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Caravan banners & cards

    private enum CaravanStatusBannerKind {
        case safe
        case overMTPLM(reduceLoadByKg: Double)
        case towVehicleUnsuitable
        case towBallLimitExceeded(reduceNoseByKg: Double)
        case noseBelowRecommended(increaseNoseByKg: Double)
        case noseAboveRecommended(reduceNoseByKg: Double)
    }

    private func resolveCaravanStatusBanner(summary: WeightSummary, profile: VehicleProfile) -> CaravanStatusBannerKind {
        if summary.isOverallSafe { return .safe }
        if summary.isOverMTPLM {
            return .overMTPLM(reduceLoadByKg: max(0, summary.totalWeightKg - profile.mtplmKg))
        }
        if summary.isTowVehicleUnsuitable {
            return .towVehicleUnsuitable
        }
        if summary.isOverTowBallLimit {
            return .towBallLimitExceeded(reduceNoseByKg: max(0, summary.estimatedNoseWeightKg - profile.effectiveMaxTowBallKg))
        }
        if summary.isNoseBelowRecommended {
            return .noseBelowRecommended(increaseNoseByKg: max(0, summary.towBallMinKg - summary.estimatedNoseWeightKg))
        }
        if summary.isNoseAboveRecommended {
            return .noseAboveRecommended(reduceNoseByKg: max(0, summary.estimatedNoseWeightKg - summary.towBallMaxKg))
        }
        return .safe
    }

    @ViewBuilder
    private func caravanStatusBanner(summary: WeightSummary, profile: VehicleProfile) -> some View {
        switch resolveCaravanStatusBanner(summary: summary, profile: profile) {
        case .safe:
            safeBanner
        case .overMTPLM(let reduceLoadByKg):
            actionableWarningBanner(
                title: "Caravan weight limit exceeded",
                lines: [
                    "Reduce load by \(kgAmountPhrase(reduceLoadByKg))",
                    "Remove items or lighten the caravan"
                ],
                background: AppColors.red,
                accessibilitySummary: "Caravan weight limit exceeded."
            )
        case .towVehicleUnsuitable:
            actionableWarningBanner(
                title: "Tow vehicle not suitable",
                lines: [
                    "The 5% minimum nose weight meets or exceeds your tow ball limit",
                    "Use a vehicle with a higher tow ball limit or a lighter caravan"
                ],
                background: AppColors.red,
                accessibilitySummary: "Tow vehicle not suitable for this caravan."
            )
        case .towBallLimitExceeded(let reduceNoseByKg):
            actionableWarningBanner(
                title: "Tow ball limit exceeded",
                lines: [
                    "Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg))",
                    "Move items rearward"
                ],
                background: AppColors.red,
                accessibilitySummary: "Tow ball limit exceeded."
            )
        case .noseBelowRecommended(let increaseNoseByKg):
            actionableWarningBanner(
                title: "Nose weight below recommended range",
                lines: [
                    "Increase nose weight by \(kgAmountPhrase(increaseNoseByKg))",
                    "Move heavier items forward"
                ],
                background: AppColors.orange,
                accessibilitySummary: "Nose weight below recommended range."
            )
        case .noseAboveRecommended(let reduceNoseByKg):
            actionableWarningBanner(
                title: "Nose weight above recommended range",
                lines: [
                    "Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg))",
                    "Move items rearward"
                ],
                background: AppColors.orange,
                accessibilitySummary: "Nose weight above recommended range."
            )
        }
    }

    private var safeBanner: some View {
        Text("SAFE")
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.white)
            .tracking(1.2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
            .accessibilityLabel("Status: safe")
    }

    private func kgAmountPhrase(_ kg: Double) -> String {
        stripKgSuffix(Formatters.kg(kg)) + " kg"
    }

    private func actionableWarningBanner(
        title: String,
        lines: [String],
        background: Color,
        accessibilitySummary: String
    ) -> some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppScreenMetrics.fieldSpacing + 2)
        .padding(.horizontal, AppScreenMetrics.controlSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func caravanCurrentWeightCard(summary: WeightSummary, profile: VehicleProfile) -> some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Current Weight")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(Formatters.kg(summary.totalWeightKg))
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(summary.isOverMTPLM ? AppColors.red : Color.accentColor)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                progressBar(
                    fill: CGFloat(summary.mtplmFillFraction(profile: profile)),
                    isOverLimit: summary.isOverMTPLM,
                    label: "Progress toward MTPLM"
                )

                HStack {
                    Text("MTPLM: \(stripKgSuffix(Formatters.kg(profile.mtplmKg))) kg")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text("Available: \(stripKgSuffix(Formatters.kg(summary.availableWeightKg))) kg")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(summary.availableWeightKg < 0 ? AppColors.red : Color.secondary)
                }
            }
        }
    }

    private func caravanNoseWeightCard(summary: WeightSummary, profile: VehicleProfile) -> some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Nose Weight")
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                let zoneBounds = summary.noseGaugeZoneBounds(profile: profile)

                NoseWeightSafeZoneGauge(
                    zoneLowKg: zoneBounds.low,
                    zoneHighKg: zoneBounds.high,
                    carMaxTowBallKg: profile.effectiveMaxTowBallKg,
                    estimatedNoseKg: summary.estimatedNoseWeightKg
                )

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    HStack {
                        Text(baseNosePercentLabel(profile: profile))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text(Formatters.kg(summary.baseNosePercentKg))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                    }

                    HStack {
                        Text("Location Impact")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text(signedKg(summary.locationImpactKg))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }

                    AppSectionDivider()

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text("Estimated Nose Weight")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                        Text(Formatters.kg(summary.estimatedNoseWeightKg))
                            .font(.largeTitle.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(summary.isOverTowBallLimit || summary.isTowVehicleUnsuitable ? AppColors.red : Color.accentColor)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppScreenMetrics.cardInteriorPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))

                HStack(spacing: 0) {
                    let effectiveLimit = profile.effectiveMaxTowBallKg
                    let carLimitOverridesMin = effectiveLimit > 0 && effectiveLimit < summary.towBallMinKg
                    let carLimitOverridesMax = effectiveLimit > 0 && effectiveLimit < summary.towBallMaxKg

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMin ? "Car Limit" : "Min (5%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                        Text(Formatters.kg(carLimitOverridesMin ? effectiveLimit : summary.towBallMinKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMin ? Color.accentColor : Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color(.separator).opacity(0.45))
                        .frame(width: 1)
                        .padding(.vertical, AppScreenMetrics.tinySpacing)

                    VStack(alignment: .trailing, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMax ? "Car Limit" : "Max (7%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                        Text(Formatters.kg(carLimitOverridesMax ? effectiveLimit : summary.towBallMaxKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMax ? Color.accentColor : Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, AppScreenMetrics.tinySpacing)
            }
        }
    }

    private func progressBar(fill: CGFloat, isOverLimit: Bool, label: String) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(isOverLimit ? AppColors.red : Color.accentColor)
                    .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(fill * 100)) percent")
    }

    private func baseNosePercentLabel(profile: VehicleProfile) -> String {
        let percent = profile.noseWeightBasePercent > 0 ? profile.noseWeightBasePercent : 6.0
        if percent.truncatingRemainder(dividingBy: 1) == 0 {
            return "Base (\(Int(percent))%)"
        }
        return String(format: "Base (%.1f%%)", percent)
    }

    private func signedKg(_ value: Double) -> String {
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
        if value < 0 { return "-\(formatted) kg" }
        if value > 0 { return "+\(formatted) kg" }
        return "0.0 kg"
    }

    private func stripKgSuffix(_ s: String) -> String {
        s.replacingOccurrences(of: " kg", with: "").trimmingCharacters(in: .whitespaces)
    }
}
