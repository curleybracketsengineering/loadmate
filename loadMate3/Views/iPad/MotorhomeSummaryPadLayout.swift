import SwiftUI

/// iPad motorhome weight summary — cutaway illustration and metric cards adapt to profile settings.
struct MotorhomeSummaryPadLayout: View {
    let profile: VehicleProfile
    let trip: Trip?
    let summary: MotorhomeWeightSummary
    let loadedItems: [LoadedItem]
    let onRenameTrip: () -> Void

    private var payloadLimitKg: Double { max(0, profile.mtplmKg - profile.calculationBaseWeightKg) }
    private var balance: MotorhomeBalanceEstimate { MotorhomeBalanceEstimate(summary: summary, loadedItems: loadedItems) }
    private var checks: [MotorhomeSummaryCheck] {
        MotorhomeSummaryCheck.build(summary: summary, profile: profile)
    }

    private var showsGarageMetrics: Bool { profile.monitorsGarageLimit }
    private var showsBikeMetrics: Bool { profile.hasBikeRack && !profile.garageLimitIncludesBikeRack }
    private var showsTowBarMetrics: Bool { summary.monitorsTowBar }

    private var garageTitle: String {
        if profile.garageLimitIncludesBikeRack, profile.hasBikeRack {
            return "Garage & Bike"
        }
        return "Garage Load"
    }

    private var garageValueKg: Double {
        if showsBikeMetrics {
            return Self.zoneWeight(in: [.garage], items: loadedItems)
        }
        return summary.garageLoadedKg
    }

    private var garageIsOverLimit: Bool {
        guard profile.maxGarageKg > 0 else { return false }
        return garageValueKg > profile.maxGarageKg
    }

    private var bikeValueKg: Double {
        Self.zoneWeight(in: [.bikeRack], items: loadedItems)
    }

    private static let heroImageMaxHeight: CGFloat = 338
    private static let metricCardHeight: CGFloat = 176

    @State private var metricColumnWidth: CGFloat = 148
    @State private var selectedCheck: MotorhomeSummaryCheck?

    private var metricsColumnCount: Int {
        var count = 3
        if showsGarageMetrics { count += 1 }
        if showsBikeMetrics { count += 1 }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacingLoose) {
            headerSection
            if let message = profile.motorhomeWeighbridgeValidation.bannerMessage {
                weighbridgeValidationBanner(message)
            }
            heroBlock
            metricsGrid
            checksSection
        }
        .padding(.top, AppScreenMetrics.sectionSpacing)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MetricColumnWidthPreferenceKey.self,
                    value: Self.metricColumnWidth(
                        availableWidth: geo.size.width,
                        columnCount: metricsColumnCount
                    )
                )
            }
        )
        .onPreferenceChange(MetricColumnWidthPreferenceKey.self) { metricColumnWidth = $0 }
        .sheet(item: $selectedCheck) { check in
            SummaryCheckDetailSheet(check: check)
        }
    }

    private func weighbridgeValidationBanner(_ message: String) -> some View {
        AppWarningBanner(message: message)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                Text("Motorhome Summary")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)

                if let trip {
                    Button(action: onRenameTrip) {
                        HStack(spacing: 6) {
                            Text(trip.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                            Image(systemName: "pencil")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rename trip \(trip.name)")
                }
            }

            Spacer(minLength: AppScreenMetrics.sectionSpacing)

            statusBadge
        }
    }

    private var statusBadge: some View {
        let isSafe = summary.isOverallSafe
        return HStack(spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: isSafe ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(isSafe ? "Safe" : "Check limits")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                Text(isSafe ? "All within limits" : primaryIssueSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppScreenMetrics.fieldSpacing)
        .padding(.vertical, AppScreenMetrics.controlSpacing)
        .background(isSafe ? AppColors.green : AppColors.orange)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSafe ? "Status safe. All within limits." : "Status check limits. \(primaryIssueSubtitle)")
    }

    private var primaryIssueSubtitle: String {
        if summary.isOverMAM { return "Gross weight over MAM" }
        if summary.isOverFrontAxle { return "Front axle limit exceeded" }
        if summary.isOverRearAxle { return "Rear axle limit exceeded" }
        if summary.isOverGarageLimit { return "Garage load over limit" }
        if summary.isTowBarMeasurementMissing { return "Enter tow bar load on Load tab" }
        if summary.isOverTowBarLimit { return "Tow bar limit exceeded" }
        return "Review weight details"
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            heroSection
            balanceScaleSection
        }
        .padding(.top, AppScreenMetrics.sectionSpacing)
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.fieldSpacing) {
            payloadMetricCard
                .frame(width: metricColumnWidth, height: Self.metricCardHeight)

            heroImage

            if showsTowBarMetrics {
                towBarMetricCard
                    .frame(width: metricColumnWidth, height: Self.metricCardHeight)
            }
        }
    }

    private var balanceScaleSection: some View {
        MotorhomeBalanceScaleView(
            isWarning: balance.isWarning,
            indicatorFraction: balance.indicatorFraction
        )
        .padding(.leading, metricColumnWidth + AppScreenMetrics.fieldSpacing)
        .padding(.trailing, showsTowBarMetrics
            ? metricColumnWidth + AppScreenMetrics.fieldSpacing
            : 0)
    }

    private var heroImage: some View {
        Image(profile.padCutawayAssetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: Self.heroImageMaxHeight)
            .accessibilityLabel("Motorhome weight zones")
    }

    // MARK: - Metrics

    private var metricsGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: AppScreenMetrics.fieldSpacing),
                count: metricsColumnCount
            ),
            alignment: .leading,
            spacing: AppScreenMetrics.fieldSpacing
        ) {
            totalWeightMetricCard
            frontAxleMetricCard
            rearAxleMetricCard
            if showsGarageMetrics { garageMetricCard }
            if showsBikeMetrics { bikeMetricCard }
        }
    }

    private var totalWeightMetricCard: some View {
        let spare = max(0, summary.availableGrossKg)
        return metricCard(
            icon: "scalemass.fill",
            iconColor: AppColors.blue,
            title: "Total Weight",
            value: summary.totalWeightKg,
            valueColor: summary.isOverMAM ? AppColors.red : AppColors.blue,
            limitLabel: "MAM: \(MotorhomeSummaryMetrics.displayKg(profile.mtplmKg))",
            fill: CGFloat(summary.mamFillFraction(profile: profile)),
            isOverLimit: summary.isOverMAM,
            barColor: AppColors.blue,
            footer: profile.mtplmKg > 0 ? "\(MotorhomeSummaryMetrics.displayKg(spare)) spare" : "Set MAM in Settings"
        )
    }

    private var frontAxleMetricCard: some View {
        let spare = max(0, profile.maxFrontAxleKg - summary.estimatedFrontAxleKg)
        return metricCard(
            icon: "circle.circle",
            iconColor: AppColors.blue,
            title: "Front Axle",
            value: summary.estimatedFrontAxleKg,
            valueColor: summary.isOverFrontAxle ? AppColors.red : AppColors.blue,
            limitLabel: "Max: \(MotorhomeSummaryMetrics.displayKg(profile.maxFrontAxleKg))",
            fill: CGFloat(summary.frontAxleFillFraction(profile: profile)),
            isOverLimit: summary.isOverFrontAxle,
            barColor: AppColors.blue,
            footer: profile.maxFrontAxleKg > 0 ? "\(MotorhomeSummaryMetrics.displayKg(spare)) spare" : "Set axle limits"
        )
    }

    private var rearAxleMetricCard: some View {
        let spare = max(0, profile.maxRearAxleKg - summary.estimatedRearAxleKg)
        return metricCard(
            icon: "circle.circle",
            iconColor: AppColors.blue,
            title: "Rear Axle",
            value: summary.estimatedRearAxleKg,
            valueColor: summary.isOverRearAxle ? AppColors.red : AppColors.blue,
            limitLabel: "Max: \(MotorhomeSummaryMetrics.displayKg(profile.maxRearAxleKg))",
            fill: CGFloat(summary.rearAxleFillFraction(profile: profile)),
            isOverLimit: summary.isOverRearAxle,
            barColor: AppColors.blue,
            footer: profile.maxRearAxleKg > 0 ? "\(MotorhomeSummaryMetrics.displayKg(spare)) spare" : "Set axle limits"
        )
    }

    private var garageMetricCard: some View {
        let spare = max(0, profile.maxGarageKg - garageValueKg)
        return metricCard(
            icon: "shippingbox.fill",
            iconColor: AppColors.purple,
            title: garageTitle,
            value: garageValueKg,
            valueColor: garageIsOverLimit ? AppColors.red : AppColors.purple,
            limitLabel: "Max: \(MotorhomeSummaryMetrics.displayKg(profile.maxGarageKg))",
            fill: profile.maxGarageKg > 0 ? CGFloat(min(max(garageValueKg / profile.maxGarageKg, 0), 1)) : 0,
            isOverLimit: garageIsOverLimit,
            barColor: AppColors.purple,
            footer: profile.maxGarageKg > 0 ? "\(MotorhomeSummaryMetrics.displayKg(spare)) spare" : "Set garage limit"
        )
    }

    private var bikeMetricCard: some View {
        metricCard(
            icon: "bicycle",
            iconColor: AppColors.purple,
            title: "Bike Load",
            value: bikeValueKg,
            valueColor: AppColors.purple,
            limitLabel: "Rear rack zone",
            fill: bikeValueKg > 0 ? 0.35 : 0,
            isOverLimit: false,
            barColor: AppColors.purple,
            footer: bikeValueKg > 0 ? "On bike rack" : "No items assigned"
        )
    }

    private var towBarMetricCard: some View {
        let value = summary.isTowBarMeasurementMissing ? 0 : summary.towBarLoadKg
        let spare = profile.maxTowBarKg > 0 ? max(0, profile.maxTowBarKg - value) : 0
        let isOver = summary.isOverTowBarLimit || summary.isTowBarMeasurementMissing
        return metricCard(
            icon: "link",
            iconColor: AppColors.green,
            title: "Tow Bar",
            value: value,
            valueColor: isOver ? AppColors.red : AppColors.green,
            limitLabel: profile.maxTowBarKg > 0
                ? "Max: \(MotorhomeSummaryMetrics.displayKg(profile.maxTowBarKg))"
                : "Set tow bar limit",
            fill: summary.isTowBarMeasurementMissing ? 0 : CGFloat(summary.towBarFillFraction(profile: profile)),
            isOverLimit: isOver,
            barColor: AppColors.green,
            footer: summary.isTowBarMeasurementMissing
                ? "Enter on Load tab"
                : (profile.maxTowBarKg > 0 ? "\(MotorhomeSummaryMetrics.displayKg(spare)) spare" : "Set tow bar limit")
        )
    }

    private var payloadMetricCard: some View {
        let remaining = max(0, summary.availableGrossKg)
        let fill = payloadLimitKg > 0 ? min(max(remaining / payloadLimitKg, 0), 1) : 0
        let isOver = summary.isOverMAM
        let percent = payloadLimitKg > 0 ? Int((remaining / payloadLimitKg) * 100) : 0
        return metricCard(
            icon: "truck.box.fill",
            iconColor: AppColors.green,
            title: "Payload Remaining",
            value: remaining,
            valueColor: isOver ? AppColors.red : AppColors.green,
            limitLabel: payloadLimitKg > 0 ? "Of \(MotorhomeSummaryMetrics.displayKg(payloadLimitKg))" : "Set MAM in Settings",
            fill: CGFloat(fill),
            isOverLimit: isOver,
            barColor: AppColors.green,
            footer: payloadLimitKg > 0 ? "\(percent)% remaining" : "Set vehicle limits"
        )
    }

    private func metricCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: Double,
        valueColor: Color,
        limitLabel: String,
        fill: CGFloat,
        isOverLimit: Bool,
        barColor: Color,
        footer: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            metricIcon(systemName: icon, color: iconColor)

            if !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Text(MotorhomeSummaryMetrics.displayKg(value))
                .font(.title.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            if !limitLabel.isEmpty {
                Text(limitLabel)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            MotorhomeSummaryMetrics.progressBar(fill: fill, color: isOverLimit ? AppColors.red : barColor)

            Text(footer)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOverLimit ? AppColors.red : iconColor)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, minHeight: Self.metricCardHeight, alignment: .topLeading)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                .stroke(LyneqoTheme.border.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func metricIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    // MARK: - Checks

    private var checksSection: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            Text("Checks & Recommendations")
                .font(.headline.weight(.bold))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: AppScreenMetrics.controlSpacing
            ) {
                ForEach(checks) { check in
                    SummaryCheckRow(check: check) {
                        selectedCheck = check
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                .stroke(LyneqoTheme.border.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private static func zoneWeight(in zones: [LoadZone], items: [LoadedItem]) -> Double {
        items.reduce(0) { sum, loaded in
            guard zones.contains(loaded.zone) else { return sum }
            let weight = loaded.item?.weightKg ?? 0
            return sum + weight * Double(max(loaded.quantity, 0))
        }
    }

    private static func metricColumnWidth(availableWidth: CGFloat, columnCount: Int) -> CGFloat {
        guard columnCount > 0 else { return 148 }
        let spacing = AppScreenMetrics.fieldSpacing
        let totalSpacing = spacing * CGFloat(max(0, columnCount - 1))
        return (availableWidth - totalSpacing) / CGFloat(columnCount)
    }
}

// MARK: - Layout

private struct MetricColumnWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 148 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
