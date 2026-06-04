import SwiftUI

/// iPad motorhome weight summary — matches the Motorhome Summary mockup.
/// Hero image and metric cards adapt to profile settings (garage limit, bike rack, tow bar).
struct MotorhomeSummaryPadLayout: View {
    let profile: VehicleProfile
    let trip: Trip?
    let summary: MotorhomeWeightSummary
    let loadedItems: [LoadedItem]
    let onRenameTrip: () -> Void

    private var payloadLimitKg: Double { max(0, profile.mtplmKg - profile.calculationBaseWeightKg) }
    private var balance: MotorhomeBalanceEstimate { MotorhomeBalanceEstimate(summary: summary, loadedItems: loadedItems) }
    private var checks: [MotorhomeSummaryCheck] {
        MotorhomeSummaryCheck.build(summary: summary, profile: profile, loadedItems: loadedItems)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            headerSection
            heroSection
            metricsRow
            checksSection
        }
        .padding(.top, AppScreenMetrics.sectionSpacing)
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

    private var heroSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Image(profile.padCutawayAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 338)
                    .accessibilityLabel("Motorhome weight zones")

                heroCalloutRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, AppScreenMetrics.sectionSpacing)
        .padding(.bottom, AppScreenMetrics.fieldSpacing)
    }

    private var heroCalloutRow: some View {
        HStack(alignment: .bottom, spacing: AppScreenMetrics.fieldSpacing) {
            heroCallout(
                title: "Front Axle",
                valueKg: summary.estimatedFrontAxleKg,
                limitKg: profile.maxFrontAxleKg,
                accent: AppColors.blue,
                isOver: summary.isOverFrontAxle
            )
            heroCallout(
                title: "Rear Axle",
                valueKg: summary.estimatedRearAxleKg,
                limitKg: profile.maxRearAxleKg,
                accent: AppColors.blue,
                isOver: summary.isOverRearAxle
            )
            if showsGarageMetrics {
                heroCallout(
                    title: garageTitle,
                    valueKg: garageValueKg,
                    limitKg: profile.maxGarageKg,
                    accent: AppColors.purple,
                    isOver: garageIsOverLimit
                )
            }
            if showsBikeMetrics {
                heroCallout(
                    title: "Bike Load",
                    valueKg: bikeValueKg,
                    limitKg: 0,
                    accent: AppColors.purple,
                    isOver: false
                )
            }
            if showsTowBarMetrics {
                heroCallout(
                    title: "Tow Bar",
                    valueKg: summary.isTowBarMeasurementMissing ? 0 : summary.towBarLoadKg,
                    limitKg: profile.maxTowBarKg,
                    accent: AppColors.green,
                    isOver: summary.isOverTowBarLimit || summary.isTowBarMeasurementMissing,
                    valuePlaceholder: summary.isTowBarMeasurementMissing ? "Not set" : nil
                )
            }
        }
    }

    private func heroCallout(
        title: String,
        valueKg: Double,
        limitKg: Double,
        accent: Color,
        isOver: Bool,
        valuePlaceholder: String? = nil
    ) -> some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(accent.opacity(0.45))
                .frame(width: 1.5, height: 28)

            VStack(spacing: AppScreenMetrics.tinySpacing) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(valuePlaceholder ?? Self.displayKg(valueKg))
                    .font(.subheadline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(isOver ? AppColors.red : accent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if limitKg > 0 {
                    Text("Max \(Self.displayKg(limitKg))")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground).opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(valuePlaceholder ?? Self.displayKg(valueKg)).")
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
            totalWeightMetricCard
            frontAxleMetricCard
            rearAxleMetricCard
            if showsGarageMetrics { garageMetricCard }
            if showsBikeMetrics { bikeMetricCard }
            if showsTowBarMetrics { towBarMetricCard }
            payloadMetricCard
            balanceMetricCard
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
            limitLabel: "MAM: \(Self.displayKg(profile.mtplmKg))",
            fill: CGFloat(summary.mamFillFraction(profile: profile)),
            isOverLimit: summary.isOverMAM,
            barColor: AppColors.blue,
            footer: profile.mtplmKg > 0 ? "\(Self.displayKg(spare)) spare" : "Set MAM in Settings"
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
            limitLabel: "Max: \(Self.displayKg(profile.maxFrontAxleKg))",
            fill: CGFloat(summary.frontAxleFillFraction(profile: profile)),
            isOverLimit: summary.isOverFrontAxle,
            barColor: AppColors.blue,
            footer: profile.maxFrontAxleKg > 0 ? "\(Self.displayKg(spare)) spare" : "Set axle limits"
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
            limitLabel: "Max: \(Self.displayKg(profile.maxRearAxleKg))",
            fill: CGFloat(summary.rearAxleFillFraction(profile: profile)),
            isOverLimit: summary.isOverRearAxle,
            barColor: AppColors.blue,
            footer: profile.maxRearAxleKg > 0 ? "\(Self.displayKg(spare)) spare" : "Set axle limits"
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
            limitLabel: "Max: \(Self.displayKg(profile.maxGarageKg))",
            fill: profile.maxGarageKg > 0 ? CGFloat(min(max(garageValueKg / profile.maxGarageKg, 0), 1)) : 0,
            isOverLimit: garageIsOverLimit,
            barColor: AppColors.purple,
            footer: profile.maxGarageKg > 0 ? "\(Self.displayKg(spare)) spare" : "Set garage limit"
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
                ? "Max: \(Self.displayKg(profile.maxTowBarKg))"
                : "Set tow bar limit",
            fill: summary.isTowBarMeasurementMissing ? 0 : CGFloat(summary.towBarFillFraction(profile: profile)),
            isOverLimit: isOver,
            barColor: AppColors.green,
            footer: summary.isTowBarMeasurementMissing
                ? "Enter on Load tab"
                : (profile.maxTowBarKg > 0 ? "\(Self.displayKg(spare)) spare" : "Set tow bar limit")
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
            limitLabel: payloadLimitKg > 0 ? "Of \(Self.displayKg(payloadLimitKg))" : "Set MAM in Settings",
            fill: CGFloat(fill),
            isOverLimit: isOver,
            barColor: AppColors.green,
            footer: payloadLimitKg > 0 ? "\(percent)% remaining" : "Set vehicle limits"
        )
    }

    private var balanceMetricCard: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                metricIcon(systemName: "scalemass.fill", color: AppColors.orange)
                Text("Balance")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Spacer(minLength: 0)
            }

            Image(systemName: "scale.3d")
                .font(.system(size: 36))
                .foregroundStyle(balance.isWarning ? AppColors.orange : AppColors.green)
                .rotationEffect(.degrees(balance.tiltDegrees))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppScreenMetrics.tinySpacing)
                .accessibilityHidden(true)

            Text(balance.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(balance.isWarning ? AppColors.orange : AppColors.green)
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
        .accessibilityLabel("Balance. \(balance.title).")
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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

            motorhomeSummaryProgressBar(fill: fill, color: isOverLimit ? AppColors.red : barColor)

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

    // MARK: - Checks

    private var checksSection: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Checks & Recommendations")
                    .font(.headline.weight(.bold))

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: AppScreenMetrics.controlSpacing
                ) {
                    ForEach(checks) { check in
                        checkRow(check)
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

            disclaimerBox
        }
    }

    private func checkRow(_ check: MotorhomeSummaryCheck) -> some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
            Image(systemName: check.isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(check.isPositive ? AppColors.green : AppColors.orange)
                .accessibilityHidden(true)
            Text(check.message)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(check.message)
    }

    private var disclaimerBox: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "scalemass")
                .font(.title3)
                .foregroundStyle(AppColors.blue)
                .accessibilityHidden(true)

            Text("MAM (\(Self.displayKg(profile.mtplmKg))) and axle limits must be observed at all times.")
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: 320, alignment: .leading)
        .background(AppColors.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reminder. MAM and axle limits must be observed at all times.")
    }

    // MARK: - Helpers

    private static func zoneWeight(in zones: [LoadZone], items: [LoadedItem]) -> Double {
        items.reduce(0) { sum, loaded in
            guard zones.contains(loaded.zone) else { return sum }
            let weight = loaded.item?.weightKg ?? 0
            return sum + weight * Double(max(loaded.quantity, 0))
        }
    }

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

private struct MotorhomeBalanceEstimate {
    let title: String
    let isWarning: Bool
    let tiltDegrees: Double

    init(summary: MotorhomeWeightSummary, loadedItems: [LoadedItem]) {
        let frontKg = Self.zoneWeight(in: [.driver, .central], items: loadedItems)
        let rearKg = Self.zoneWeight(in: [.back, .garage, .bikeRack], items: loadedItems)

        if summary.frontAxleImpactKg > summary.rearAxleImpactKg + 80, frontKg > rearKg {
            title = "Front-heavy"
            isWarning = true
            tiltDegrees = -18
        } else if summary.rearAxleImpactKg > summary.frontAxleImpactKg + 80, rearKg > frontKg {
            title = "Rear-heavy"
            isWarning = true
            tiltDegrees = 18
        } else {
            title = "Well balanced"
            isWarning = false
            tiltDegrees = 0
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

// MARK: - Checks

private struct MotorhomeSummaryCheck: Identifiable {
    let id: String
    let message: String
    let isPositive: Bool

    static func build(
        summary: MotorhomeWeightSummary,
        profile: VehicleProfile,
        loadedItems: [LoadedItem]
    ) -> [MotorhomeSummaryCheck] {
        var checks: [MotorhomeSummaryCheck] = [
            MotorhomeSummaryCheck(
                id: "front",
                message: summary.isOverFrontAxle
                    ? "Front axle load exceeds the limit"
                    : "Front axle load is within the limit",
                isPositive: !summary.isOverFrontAxle
            ),
            MotorhomeSummaryCheck(
                id: "rear",
                message: summary.isOverRearAxle
                    ? "Rear axle load exceeds the limit"
                    : "Rear axle load is within the limit",
                isPositive: !summary.isOverRearAxle
            ),
        ]

        if profile.monitorsGarageLimit {
            checks.append(
                MotorhomeSummaryCheck(
                    id: "garage",
                    message: summary.isOverGarageLimit
                        ? "Garage load exceeds the limit"
                        : "Garage load is within the limit",
                    isPositive: !summary.isOverGarageLimit
                )
            )
        }

        if summary.monitorsTowBar {
            checks.append(
                MotorhomeSummaryCheck(
                    id: "towbar",
                    message: summary.isOverTowBarLimit || summary.isTowBarMeasurementMissing
                        ? "Tow bar load is not within the limit"
                        : "Tow bar load is within the limit",
                    isPositive: !summary.isOverTowBarLimit && !summary.isTowBarMeasurementMissing
                )
            )
        }

        checks.append(
            MotorhomeSummaryCheck(
                id: "payload",
                message: summary.isOverMAM
                    ? "Payload exceeds your available limit"
                    : "Payload is within your limit",
                isPositive: !summary.isOverMAM
            )
        )

        return checks
    }
}

// MARK: - Shared chrome

private func motorhomeSummaryProgressBar(fill: CGFloat, color: Color) -> some View {
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
