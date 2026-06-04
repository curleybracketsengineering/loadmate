import SwiftUI

/// iPad caravan weight summary — matches the Caravan Weight Summary mockup.
struct CaravanSummaryPadLayout: View {
    let profile: VehicleProfile
    let trip: Trip?
    let summary: WeightSummary
    let loadedItems: [LoadedItem]
    let onRenameTrip: () -> Void

    @State private var selectedCheck: CaravanSummaryCheck?

    private var towBallLimitKg: Double { profile.effectiveMaxTowBallKg }
    private var payloadLimitKg: Double { max(0, profile.mtplmKg - profile.calculationBaseWeightKg) }
    private var payloadUsedKg: Double { summary.loadedWeightKg }
    private var balance: CaravanBalanceEstimate { CaravanBalanceEstimate(summary: summary, loadedItems: loadedItems) }
    private var checks: [CaravanSummaryCheck] { CaravanSummaryCheck.build(summary: summary, profile: profile, loadedItems: loadedItems) }

    /// Caravan hero graphic — 30% taller than the original 260pt cap for a stronger weight-tab focal point.
    private static let heroImageMaxHeight: CGFloat = 338
    private static let heroConnectorHeight: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.bottom, AppScreenMetrics.fieldSpacing)
            heroSection
                .padding(.bottom, AppScreenMetrics.sectionSpacingLoose)
            metricsRow
                .padding(.top, AppScreenMetrics.smallSpacing)
                .padding(.bottom, AppScreenMetrics.sectionSpacingLoose)
            checksSection
                .padding(.top, AppScreenMetrics.smallSpacing)
                .padding(.bottom, AppScreenMetrics.sectionSpacingLoose)
            CaravanSummaryDisclaimerBanner(showsTopDivider: false)
        }
        .sheet(item: $selectedCheck) { check in
            CaravanSummaryCheckDetailSheet(check: check)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                Text("Caravan Summary")
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
        if summary.isOverMTPLM { return "Caravan weight over MTPLM" }
        if summary.isTowVehicleUnsuitable { return "Tow vehicle may not be suitable" }
        if summary.isOverTowBallLimit { return "Tow ball limit exceeded" }
        if summary.isNoseBelowRecommended { return "Nose weight below recommended range" }
        if summary.isNoseAboveRecommended { return "Nose weight above recommended range" }
        return "Review weight details"
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            Image("CaravanSummary")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: Self.heroImageMaxHeight)
                .accessibilityHidden(true)

            Rectangle()
                .fill(AppColors.green.opacity(summary.isOverTowBallLimit || summary.isTowVehicleUnsuitable ? 0.35 : 0.55))
                .frame(width: 2, height: Self.heroConnectorHeight)

            noseWeightHeroCard
                .padding(.top, AppScreenMetrics.tinySpacing)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppScreenMetrics.tinySpacing)
        .padding(.bottom, AppScreenMetrics.fieldSpacing)
    }

    private var noseWeightHeroCard: some View {
        let limit = towBallLimitKg
        let value = summary.estimatedNoseWeightKg
        let spare = limit > 0 ? limit - value : 0
        let isOver = summary.isOverTowBallLimit || summary.isTowVehicleUnsuitable
        let accent = isOver ? AppColors.red : AppColors.green

        return VStack(spacing: AppScreenMetrics.tinySpacing) {
            Text("Towbar / Nose Weight")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.blue)

            Text(Self.displayKg(value))
                .font(.title.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(accent)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            if limit > 0 {
                Text("Max \(Self.displayKg(limit))")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, AppScreenMetrics.fieldSpacing)
        .padding(.vertical, AppScreenMetrics.controlSpacing)
        .frame(minWidth: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Towbar nose weight \(Self.displayKg(value)). \(noseOverlayFooter(limit: limit, spare: spare, isOver: isOver))")
    }

    private func noseOverlayFooter(limit: Double, spare: Double, isOver: Bool) -> String {
        if summary.isTowVehicleUnsuitable { return "Tow vehicle not suitable" }
        if isOver, limit > 0 { return "\(Self.displayKg(abs(spare))) over limit" }
        if limit > 0, spare >= 0 { return "\(Self.displayKg(spare)) remaining" }
        return "Enter tow ball limit in Settings"
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.fieldSpacing) {
            caravanWeightMetricCard
            payloadMetricCard
            balanceMetricCard
        }
    }

    private var caravanWeightMetricCard: some View {
        metricCard(
            icon: "caravan.fill",
            iconColor: AppColors.blue,
            title: "Caravan Weight",
            value: summary.totalWeightKg,
            valueColor: summary.isOverMTPLM ? AppColors.red : AppColors.blue,
            limitLabel: "MTPLM: \(Self.displayKg(profile.mtplmKg))",
            fill: CGFloat(summary.mtplmFillFraction(profile: profile)),
            isOverLimit: summary.isOverMTPLM,
            barColor: AppColors.blue,
            footer: caravanFooter
        )
    }

    private var payloadMetricCard: some View {
        let fill = payloadLimitKg > 0 ? min(max(payloadUsedKg / payloadLimitKg, 0), 1) : 0
        let isOver = payloadLimitKg > 0 && payloadUsedKg > payloadLimitKg
        return metricCard(
            icon: "bag.fill",
            iconColor: AppColors.purple,
            title: "Payload Used",
            value: payloadUsedKg,
            valueColor: isOver ? AppColors.red : AppColors.purple,
            limitLabel: payloadLimitKg > 0 ? "Limit: \(Self.displayKg(payloadLimitKg))" : "Set MTPLM in Settings",
            fill: CGFloat(fill),
            isOverLimit: isOver,
            barColor: AppColors.purple,
            footer: payloadFooter(isOver: isOver)
        )
    }

    private var balanceMetricCard: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                metricIcon(systemName: "scalemass.fill", color: AppColors.orange)
                Text("Balance Estimate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Spacer(minLength: 0)
            }

            balanceScaleIcon
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppScreenMetrics.tinySpacing)

            Text(balance.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(balance.isWarning ? AppColors.orange : AppColors.green)
                .fixedSize(horizontal: false, vertical: true)

            Text(balance.detail)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Balance estimate. \(balance.title). \(balance.detail)")
    }

    private var balanceScaleIcon: some View {
        let tilt: Double = {
            switch balance.tilt {
            case .frontHeavy: return -18
            case .rearHeavy: return 18
            case .level: return 0
            }
        }()
        return Image(systemName: "scale.3d")
            .font(.system(size: 36))
            .foregroundStyle(balance.isWarning ? AppColors.orange : AppColors.green)
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
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
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                metricIcon(systemName: icon, color: iconColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }

            Text(Self.displayKg(value))
                .font(.title.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(limitLabel)
                .font(.caption)
                .foregroundStyle(Color.secondary)

            summaryProgressBar(fill: fill, color: isOverLimit ? AppColors.red : barColor)

            Text(footer)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOverLimit ? AppColors.red : iconColor)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
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

    private var caravanFooter: String {
        if profile.mtplmKg > 0 {
            return "\(Int(summary.mtplmPercent))% of MTPLM"
        }
        return "Set MTPLM in Settings"
    }

    private func payloadFooter(isOver: Bool) -> String {
        guard payloadLimitKg > 0 else { return "Set caravan limits" }
        if isOver {
            return "\(Self.displayKg(payloadUsedKg - payloadLimitKg)) over"
        }
        let percent = Int((payloadUsedKg / payloadLimitKg) * 100)
        return "\(percent)% used"
    }

    // MARK: - Checks

    private var checksSection: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            Text("Checks & Recommendations")
                .font(.headline.weight(.bold))

            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: AppScreenMetrics.controlSpacing
            ) {
                ForEach(checks) { check in
                    CaravanSummaryCheckRow(check: check) {
                        selectedCheck = check
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Formatting

    private static func displayKg(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "\(number) kg"
    }
}

// MARK: - Balance

private struct CaravanBalanceEstimate {
    enum Tilt {
        case frontHeavy
        case rearHeavy
        case level
    }

    let title: String
    let detail: String
    let isWarning: Bool
    let tilt: Tilt

    init(summary: WeightSummary, loadedItems: [LoadedItem]) {
        let frontKg = Self.zoneWeight(in: [.frontLocker, .front], items: loadedItems)
        let rearKg = Self.zoneWeight(in: [.rear, .bikeRack], items: loadedItems)

        if summary.locationImpactKg > 8 || (frontKg > rearKg * 1.25 && frontKg > 15) {
            title = "Slightly front-heavy"
            detail = "Consider moving some load rearwards"
            isWarning = true
            tilt = .frontHeavy
        } else if summary.locationImpactKg < -8 || (rearKg > frontKg * 1.25 && rearKg > 15) {
            title = "Slightly rear-heavy"
            detail = "Consider moving some load forward for stability"
            isWarning = true
            tilt = .rearHeavy
        } else if summary.isNoseBelowRecommended {
            title = "Nose weight low"
            detail = "Move heavier items toward the front"
            isWarning = true
            tilt = .frontHeavy
        } else if summary.isNoseAboveRecommended {
            title = "Nose weight high"
            detail = "Move heavier items toward the rear"
            isWarning = true
            tilt = .rearHeavy
        } else {
            title = "Well balanced"
            detail = "Load is evenly distributed"
            isWarning = false
            tilt = .level
        }
    }

    private static func zoneWeight(in zones: [LoadZone], items: [LoadedItem]) -> Double {
        items.reduce(0) { sum, loaded in
            guard zones.contains(loaded.zone) else { return sum }
            let weight = loaded.item?.weightKg ?? 0
            return sum + weight * Double(max(loaded.quantity, 0))
        }
    }
}

// MARK: - Disclaimer banner

struct CaravanSummaryDisclaimerBanner: View {
    var showsTopDivider = true

    var body: some View {
        VStack(spacing: 0) {
            if showsTopDivider {
                AppSectionDivider()
            }

            HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: "scalemass")
                    .font(.title3)
                    .foregroundStyle(AppColors.blue)
                    .accessibilityHidden(true)

                Text("These figures are estimates. Always confirm with a nose weight gauge before travelling.")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.blue.opacity(0.08))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Disclaimer. These figures are estimates. Always confirm with a nose weight gauge before travelling.")
        }
    }
}

// MARK: - Shared chrome

private func summaryProgressBar(fill: CGFloat, color: Color) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(Color(.tertiarySystemFill))
            Capsule()
                .fill(color)
                .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
        }
    }
    .frame(height: 8)
}
