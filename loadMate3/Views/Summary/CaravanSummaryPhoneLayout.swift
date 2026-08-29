import SwiftUI

/// iPhone caravan weight summary — dashboard layout with hero graphic and checks.
struct CaravanSummaryPhoneLayout: View {
    let profile: VehicleProfile
    let trip: Trip?
    let summary: WeightSummary
    let loadedItems: [LoadedItem]
    let onRenameTrip: () -> Void

    @State private var selectedCheck: CaravanSummaryCheck?

    private var checks: [CaravanSummaryCheck] {
        CaravanSummaryCheck.build(summary: summary, profile: profile, loadedItems: loadedItems)
    }

    private var sortedChecks: [CaravanSummaryCheck] {
        checks.sorted { !$0.isPositive && $1.isPositive }
    }

    /// Vertical centre of the nose-weight callout in the hero (0 = top).
    private static let heroNoseWeightCenterYFraction: CGFloat = 0.22
    private static let heroNoseWeightCenterXFraction: CGFloat = 0.58
    private static let heroNoseWeightCenterXOffset: CGFloat = -40
    private static let heroImageMaxHeight: CGFloat = 200

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            headerSection
            statusBanner
            currentWeightCard
            noseWeightCard
            checksCard
        }
        .sheet(item: $selectedCheck) { check in
            CaravanSummaryCheckDetailSheet(check: check)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
            Text("Caravan")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.primary)

            if let trip {
                Button(action: onRenameTrip) {
                    HStack(spacing: 6) {
                        Text(trip.name)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Loading configuration \(trip.name). Rename loading configuration.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        switch resolveStatusBanner() {
        case .safe:
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
                Text("SAFE")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
            .accessibilityLabel("Status: safe")

        case .overMTPLM(let reduceLoadByKg):
            warningBanner(
                title: "Caravan weight limit exceeded",
                lines: [
                    "Reduce load by \(kgAmountPhrase(reduceLoadByKg))",
                    "Remove items or lighten the caravan"
                ],
                background: AppColors.red,
                accessibilitySummary: "Caravan weight limit exceeded."
            )

        case .towVehicleUnsuitable:
            warningBanner(
                title: "Tow vehicle not suitable",
                lines: [
                    "The 5% minimum nose weight meets or exceeds your tow ball limit",
                    "Use a vehicle with a higher tow ball limit or a lighter caravan"
                ],
                background: AppColors.red,
                accessibilitySummary: "Tow vehicle not suitable for this caravan."
            )

        case .towBallLimitExceeded(let reduceNoseByKg):
            warningBanner(
                title: "Tow ball limit exceeded",
                lines: [
                    "Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg))",
                    "Move items rearward"
                ],
                background: AppColors.red,
                accessibilitySummary: "Tow ball limit exceeded."
            )

        case .noseBelowRecommended(let increaseNoseByKg):
            warningBanner(
                title: "Nose weight below recommended range",
                lines: [
                    "Increase nose weight by \(kgAmountPhrase(increaseNoseByKg))",
                    "Move heavier items forward"
                ],
                background: AppColors.orange,
                accessibilitySummary: "Nose weight below recommended range."
            )

        case .noseAboveRecommended(let reduceNoseByKg):
            warningBanner(
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

    private enum StatusBannerKind {
        case safe
        case overMTPLM(reduceLoadByKg: Double)
        case towVehicleUnsuitable
        case towBallLimitExceeded(reduceNoseByKg: Double)
        case noseBelowRecommended(increaseNoseByKg: Double)
        case noseAboveRecommended(reduceNoseByKg: Double)
    }

    private func resolveStatusBanner() -> StatusBannerKind {
        if summary.isOverallSafe { return .safe }
        if summary.isOverMTPLM {
            return .overMTPLM(reduceLoadByKg: max(0, summary.totalWeightKg - profile.mtplmKg))
        }
        if summary.isTowVehicleUnsuitable { return .towVehicleUnsuitable }
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

    private func warningBanner(
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

    // MARK: - Current weight

    private var currentWeightCard: some View {
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
                    isOverLimit: summary.isOverMTPLM
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

    // MARK: - Nose weight

    private var noseWeightCard: some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Nose Weight")
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                noseWeightHeroSection

                let zoneBounds = summary.noseGaugeZoneBounds(profile: profile)
                NoseWeightSafeZoneGauge(
                    zoneLowKg: zoneBounds.low,
                    zoneHighKg: zoneBounds.high,
                    carMaxTowBallKg: profile.effectiveMaxTowBallKg,
                    estimatedNoseKg: summary.estimatedNoseWeightKg,
                    showsTitle: false
                )

                noseWeightBreakdown
            }
        }
    }

    private var noseWeightHeroSection: some View {
        ZStack {
            Image("iphoneCaravan")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: Self.heroImageMaxHeight)
                .accessibilityHidden(true)

            GeometryReader { geo in
                noseWeightCallout
                    .position(
                        x: geo.size.width * Self.heroNoseWeightCenterXFraction + Self.heroNoseWeightCenterXOffset,
                        y: geo.size.height * Self.heroNoseWeightCenterYFraction
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var noseWeightCallout: some View {
        let isOver = summary.isOverTowBallLimit || summary.isTowVehicleUnsuitable
        let accent = isOver ? AppColors.red : Color.accentColor

        return VStack(spacing: 2) {
            Text(stripKgSuffix(Formatters.kg(summary.estimatedNoseWeightKg)) + " kg")
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(accent)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text("Estimated")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated nose weight \(Formatters.kg(summary.estimatedNoseWeightKg))")
    }

    private var noseWeightBreakdown: some View {
        VStack(spacing: AppScreenMetrics.controlSpacing) {
            HStack {
                Text(baseNosePercentLabel)
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
                    .foregroundStyle(
                        summary.isOverTowBallLimit || summary.isTowVehicleUnsuitable
                            ? AppColors.red
                            : Color.accentColor
                    )
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
    }

    // MARK: - Checks

    private var checksCard: some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Checks & Recommendations")
                    .font(.headline.weight(.bold))

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(sortedChecks) { check in
                        CaravanSummaryCheckRow(check: check) {
                            selectedCheck = check
                        }
                        if check.id != sortedChecks.last?.id {
                            AppSectionDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func progressBar(fill: CGFloat, isOverLimit: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LyneqoTheme.softTeal)
                Capsule()
                    .fill(isOverLimit ? AppColors.red : Color.accentColor)
                    .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Progress toward MTPLM")
        .accessibilityValue("\(Int(fill * 100)) percent")
    }

    private var baseNosePercentLabel: String {
        let percent = profile.noseWeightBasePercent > 0 ? profile.noseWeightBasePercent : 6.0
        if percent.truncatingRemainder(dividingBy: 1) == 0 {
            return "Base (\(Int(percent))%)"
        }
        return String(format: "Base (%.1f%%)", percent)
    }

    private func kgAmountPhrase(_ kg: Double) -> String {
        stripKgSuffix(Formatters.kg(kg)) + " kg"
    }

    private func signedKg(_ value: Double) -> String {
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: abs(value)))
            ?? String(format: "%.1f", abs(value))
        if value < 0 { return "-\(formatted) kg" }
        if value > 0 { return "+\(formatted) kg" }
        return "0.0 kg"
    }

    private func stripKgSuffix(_ s: String) -> String {
        s.replacingOccurrences(of: " kg", with: "").trimmingCharacters(in: .whitespaces)
    }
}
