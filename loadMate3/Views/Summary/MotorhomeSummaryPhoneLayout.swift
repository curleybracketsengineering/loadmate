import SwiftUI

/// iPhone motorhome weight summary — premium dashboard layout with metric cards.
struct MotorhomeSummaryPhoneLayout: View {
    let profile: VehicleProfile
    let trip: Trip?
    let summary: MotorhomeWeightSummary
    let loadedItems: [LoadedItem]
    let onRenameTrip: () -> Void
    var onNavigateToLocations: (() -> Void)?

    private var balance: MotorhomeBalanceEstimate { MotorhomeBalanceEstimate(summary: summary, loadedItems: loadedItems) }
    private var checks: [MotorhomeSummaryCheck] {
        MotorhomeSummaryCheck.build(summary: summary, profile: profile)
    }

    @State private var selectedCheck: MotorhomeSummaryCheck?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            MotorhomeSummaryHeaderView(trip: trip, onRenameTrip: onRenameTrip)

            LimitWarningCard(
                isSafe: summary.isOverallSafe,
                detail: MotorhomeSummaryPrimaryIssue.subtitle(summary: summary),
                onTap: openPrimaryCheck
            )

            if let message = profile.motorhomeWeighbridgeValidation.bannerMessage {
                AppWarningBanner(message: message)
                    .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
            }

            MotorhomeVisualBalanceCard(balance: balance)

            TotalWeightSummaryCard(summary: summary, profile: profile)

            axleCardsRow

            ChecksRecommendationsCard(
                checks: checks,
                balance: balance,
                onSelectCheck: { selectedCheck = $0 },
                onBalancePlacementTap: onNavigateToLocations
            )
        }
        .sheet(item: $selectedCheck) { check in
            MotorhomeSummaryCheckDetailSheet(check: check)
        }
    }

    // MARK: - Rows

    private var axleCardsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            AxleWeightCard(
                title: "Front Axle",
                valueKg: summary.estimatedFrontAxleKg,
                maxKg: profile.maxFrontAxleKg,
                fill: summary.frontAxleFillFraction(profile: profile),
                isOver: summary.isOverFrontAxle
            )
            .frame(maxWidth: .infinity)

            AxleWeightCard(
                title: "Rear Axle",
                valueKg: summary.estimatedRearAxleKg,
                maxKg: profile.maxRearAxleKg,
                fill: summary.rearAxleFillFraction(profile: profile),
                isOver: summary.isOverRearAxle
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func openPrimaryCheck() {
        guard !summary.isOverallSafe else { return }
        if let failing = checks.first(where: { !$0.isPositive }) {
            selectedCheck = failing
        }
    }
}
