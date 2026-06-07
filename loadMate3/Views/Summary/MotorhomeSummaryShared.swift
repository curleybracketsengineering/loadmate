import SwiftUI

// MARK: - Metrics helpers

enum MotorhomeSummaryMetrics {
    static func displayKg(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "\(number) kg"
    }

    static func progressBar(fill: CGFloat, color: Color) -> some View {
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
}

// MARK: - Primary issue

enum MotorhomeSummaryPrimaryIssue {
    static func subtitle(summary: MotorhomeWeightSummary) -> String {
        if summary.isOverMAM { return "Gross weight over MAM" }
        if summary.isOverFrontAxle { return "Front axle load exceeds the limit" }
        if summary.isOverRearAxle { return "Rear axle load exceeds the limit" }
        if summary.isOverGarageLimit { return "Garage load over limit" }
        if summary.isTowBarMeasurementMissing { return "Enter tow bar load on Load tab" }
        if summary.isOverTowBarLimit { return "Tow bar limit exceeded" }
        return "Review weight details"
    }
}

// MARK: - Card chrome

struct MotorhomeSummaryCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(AppScreenMetrics.cardInteriorPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct MotorhomeSummaryMetricIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }
}

// MARK: - Balance

struct MotorhomeBalanceEstimate {
    let isWarning: Bool
    /// 0 = front-heavy, 0.5 = balanced, 1 = rear-heavy (for the balance scale marker).
    let indicatorFraction: CGFloat

    init(summary: MotorhomeWeightSummary, loadedItems: [LoadedItem]) {
        let frontKg = Self.zoneWeight(in: [.driver, .central], items: loadedItems)
        let rearKg = Self.zoneWeight(in: [.back, .garage, .bikeRack], items: loadedItems)

        if summary.frontAxleImpactKg > summary.rearAxleImpactKg + 80, frontKg > rearKg {
            isWarning = true
            indicatorFraction = 0.14
        } else if summary.rearAxleImpactKg > summary.frontAxleImpactKg + 80, rearKg > frontKg {
            isWarning = true
            indicatorFraction = 0.86
        } else {
            isWarning = false
            indicatorFraction = 0.5
        }
    }

    var placementMessage: String {
        indicatorFraction < 0.5
            ? "Review item placement to shift weight rearward"
            : "Review item placement to shift weight forward"
    }

    private static func zoneWeight(in zones: [LoadZone], items: [LoadedItem]) -> Double {
        items.reduce(0) { sum, loaded in
            guard zones.contains(loaded.zone) else { return sum }
            let weight = loaded.item?.weightKg ?? 0
            return sum + weight * Double(max(loaded.quantity, 0))
        }
    }
}

// MARK: - Header

struct MotorhomeSummaryHeaderView: View {
    let trip: Trip?
    let onRenameTrip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
            Text("Motorhome")
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
                .accessibilityLabel("Trip \(trip.name). Rename trip.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Limit warning

struct LimitWarningCard: View {
    let isSafe: Bool
    let detail: String
    var onTap: (() -> Void)?

    private var background: Color { isSafe ? AppColors.green : AppColors.orange }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: isSafe ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isSafe ? "All within limits" : "Check limits")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                    if !isSafe {
                        Text(detail)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isSafe {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .padding(.horizontal, AppScreenMetrics.controlSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSafe ? "All within limits." : "Check limits. \(detail)")
        .accessibilityHint(isSafe ? "" : "Opens guidance for the primary issue")
    }
}

// MARK: - Visual + balance

struct MotorhomeVisualBalanceCard: View {
    let balance: MotorhomeBalanceEstimate
    private static let heroImageMaxHeight: CGFloat = 260

    var body: some View {
        MotorhomeSummaryCard {
            VStack(spacing: AppScreenMetrics.fieldSpacing) {
                Image("motorhome_3d_summary")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: Self.heroImageMaxHeight)
                    .padding(.vertical, AppScreenMetrics.smallSpacing)
                    .accessibilityLabel("Motorhome weight zones")

                MotorhomeBalanceScaleView(
                    isWarning: balance.isWarning,
                    indicatorFraction: balance.indicatorFraction
                )
            }
        }
    }
}

// MARK: - Total weight

struct TotalWeightSummaryCard: View {
    let summary: MotorhomeWeightSummary
    let profile: VehicleProfile

    private var valueColor: Color { summary.isOverMAM ? AppColors.red : AppColors.blue }
    private var barColor: Color { summary.isOverMAM ? AppColors.red : AppColors.blue }

    private var footer: String {
        let over = max(0, summary.totalWeightKg - profile.mtplmKg)
        if summary.isOverMAM {
            return "\(MotorhomeSummaryMetrics.displayKg(over)) over"
        }
        if profile.mtplmKg > 0 {
            return "\(MotorhomeSummaryMetrics.displayKg(summary.availableGrossKg)) spare"
        }
        return "Set MAM in Settings"
    }

    var body: some View {
        MotorhomeSummaryCard {
            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                    HStack(spacing: 6) {
                        MotorhomeSummaryMetricIcon(systemName: "scalemass.fill", color: AppColors.blue)
                        Text("Total Weight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                    }
                    Text(MotorhomeSummaryMetrics.displayKg(summary.totalWeightKg))
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(valueColor)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("MAM: \(MotorhomeSummaryMetrics.displayKg(profile.mtplmKg))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: AppScreenMetrics.smallSpacing)

                VStack(alignment: .trailing, spacing: 6) {
                    MotorhomeSummaryMetrics.progressBar(
                        fill: CGFloat(summary.mamFillFraction(profile: profile)),
                        color: barColor
                    )
                    .frame(width: 120)
                    Text(footer)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(barColor)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Axle card

struct AxleWeightCard: View {
    let title: String
    let valueKg: Double
    let maxKg: Double
    let fill: Double
    let isOver: Bool

    private var accent: Color { isOver ? AppColors.red : AppColors.blue }

    private var footer: String {
        let over = max(0, valueKg - maxKg)
        let spare = max(0, maxKg - valueKg)
        if isOver {
            return "\(MotorhomeSummaryMetrics.displayKg(over)) over"
        }
        if maxKg > 0 {
            return "\(MotorhomeSummaryMetrics.displayKg(spare)) spare"
        }
        return "Set axle limits"
    }

    var body: some View {
        MotorhomeSummaryCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                MotorhomeSummaryMetricIcon(systemName: "circle.circle", color: accent)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)

                Text(MotorhomeSummaryMetrics.displayKg(valueKg))
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("Max: \(MotorhomeSummaryMetrics.displayKg(maxKg))")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)

                MotorhomeSummaryMetrics.progressBar(fill: CGFloat(fill), color: accent)

                Text(footer)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Balance placement row

struct MotorhomeBalancePlacementRow: View {
    let message: String
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.blue)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(message)
        .accessibilityHint("Opens the Locations tab")
    }
}

// MARK: - Checks & recommendations

struct ChecksRecommendationsCard: View {
    let checks: [MotorhomeSummaryCheck]
    let balance: MotorhomeBalanceEstimate
    let onSelectCheck: (MotorhomeSummaryCheck) -> Void
    var onBalancePlacementTap: (() -> Void)?

    private var sortedChecks: [MotorhomeSummaryCheck] {
        checks.sorted { !$0.isPositive && $1.isPositive }
    }

    var body: some View {
        MotorhomeSummaryCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Checks & Recommendations")
                    .font(.headline.weight(.bold))

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(sortedChecks) { check in
                        MotorhomeSummaryCheckRow(check: check) {
                            onSelectCheck(check)
                        }
                        if check.id != sortedChecks.last?.id || balance.isWarning {
                            AppSectionDivider()
                        }
                    }

                    if balance.isWarning {
                        MotorhomeBalancePlacementRow(
                            message: balance.placementMessage,
                            onTap: onBalancePlacementTap
                        )
                    }
                }
            }
        }
    }
}
