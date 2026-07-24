import SwiftUI

enum MotorhomeSummaryContent {
    enum StatusBannerKind {
        case safe
        case overMAM(reduceLoadByKg: Double)
        case frontAxleExceeded(reduceByKg: Double)
        case rearAxleExceeded(reduceByKg: Double)
        case garageExceeded(reduceByKg: Double)
        case towBarMeasurementMissing
        case towBarLimitExceeded(reduceByKg: Double)
    }

    static func resolveStatusBanner(summary: MotorhomeWeightSummary, profile: VehicleProfile) -> StatusBannerKind {
        if summary.isOverallSafe { return .safe }
        if summary.isOverMAM {
            return .overMAM(reduceLoadByKg: max(0, summary.totalWeightKg - profile.mtplmKg))
        }
        if summary.isOverFrontAxle {
            return .frontAxleExceeded(reduceByKg: max(0, summary.estimatedFrontAxleKg - profile.maxFrontAxleKg))
        }
        if summary.isOverRearAxle {
            return .rearAxleExceeded(reduceByKg: max(0, summary.estimatedRearAxleKg - profile.maxRearAxleKg))
        }
        if summary.isOverGarageLimit {
            return .garageExceeded(reduceByKg: max(0, summary.garageLoadedKg - profile.maxGarageKg))
        }
        if summary.isTowBarMeasurementMissing {
            return .towBarMeasurementMissing
        }
        if summary.isOverTowBarLimit {
            return .towBarLimitExceeded(reduceByKg: max(0, summary.towBarLoadKg - profile.maxTowBarKg))
        }
        return .safe
    }

    @ViewBuilder
    static func grossWeightCard(summary: MotorhomeWeightSummary, profile: VehicleProfile) -> some View {
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
                        .foregroundStyle(summary.isOverMAM ? AppColors.red : Color.accentColor)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                axleProgressBar(
                    fill: CGFloat(summary.mamFillFraction(profile: profile)),
                    isOverLimit: summary.isOverMAM,
                    accessibilityLabel: "Progress toward MAM"
                )

                HStack {
                    Text("MAM: \(stripKg(Formatters.kg(profile.mtplmKg))) kg")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text("Available: \(stripKg(Formatters.kg(summary.availableGrossKg))) kg")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(summary.availableGrossKg < 0 ? AppColors.red : Color.secondary)
                }
            }
        }
    }

    @ViewBuilder
    static func towBarCard(summary: MotorhomeWeightSummary, profile: VehicleProfile) -> some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Tow bar load")
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text("Entered on the Load tab for this trip. Included in rear axle and gross weight; not estimated from item positions.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline) {
                    Text(summary.isTowBarMeasurementMissing ? "Not set" : Formatters.kg(summary.towBarLoadKg))
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(summary.isOverTowBarLimit || summary.isTowBarMeasurementMissing ? AppColors.red : Color.accentColor)
                    Spacer()
                    if profile.maxTowBarKg > 0 {
                        Text("Max \(stripKg(Formatters.kg(profile.maxTowBarKg))) kg")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }

                if profile.maxTowBarKg > 0, !summary.isTowBarMeasurementMissing {
                    axleProgressBar(
                        fill: CGFloat(summary.towBarFillFraction(profile: profile)),
                        isOverLimit: summary.isOverTowBarLimit,
                        accessibilityLabel: "Progress toward tow bar limit"
                    )
                }
            }
        }
    }

    @ViewBuilder
    static func garageCard(summary: MotorhomeWeightSummary, profile: VehicleProfile) -> some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Garage (overhang)")
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(garageLimitCaption(profile: profile))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline) {
                    Text(Formatters.kg(summary.garageLoadedKg))
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(summary.isOverGarageLimit ? AppColors.red : Color.accentColor)
                    Spacer()
                    Text("Max \(stripKg(Formatters.kg(profile.maxGarageKg))) kg")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                axleProgressBar(
                    fill: CGFloat(summary.garageFillFraction(profile: profile)),
                    isOverLimit: summary.isOverGarageLimit,
                    accessibilityLabel: "Progress toward garage weight limit"
                )

                if summary.garageLoadedKg == 0 {
                    Text(garageLimitEmptyHint(profile: profile))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }
            }
        }
    }

    @ViewBuilder
    static func axleCard(
        title: String,
        estimatedKg: Double,
        limitKg: Double,
        impactKg: Double,
        fillFraction: CGFloat,
        isOverLimit: Bool,
        accessibilityLabel: String
    ) -> some View {
        SummaryMetricCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                HStack(alignment: .firstTextBaseline) {
                    Text(Formatters.kg(estimatedKg))
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(isOverLimit ? AppColors.red : Color.accentColor)
                    Spacer()
                    Text("Max \(stripKg(Formatters.kg(limitKg))) kg")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                axleProgressBar(fill: fillFraction, isOverLimit: isOverLimit, accessibilityLabel: accessibilityLabel)

                HStack {
                    Text("Location impact")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(signedKg(impactKg))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
            }
        }
    }

    private static func axleProgressBar(fill: CGFloat, isOverLimit: Bool, accessibilityLabel: String) -> some View {
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
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int(fill * 100)) percent")
    }

    private static func garageLimitCaption(profile: VehicleProfile) -> String {
        if profile.garageLimitIncludesBikeRack {
            return "Trip items in the Garage and Bike Rack zones, versus your combined rear limit. Also included in rear axle estimate."
        }
        return "Trip items in the Garage zone only. Bike rack items are not included in this limit. Also included in rear axle estimate."
    }

    private static func garageLimitEmptyHint(profile: VehicleProfile) -> String {
        if profile.garageLimitIncludesBikeRack {
            return "Assign items to the Garage or Bike Rack zone on the Locations tab."
        }
        return "Assign items to the Garage zone on the Locations tab."
    }

    private static func stripKg(_ s: String) -> String {
        s.replacingOccurrences(of: " kg", with: "").trimmingCharacters(in: .whitespaces)
    }

    private static func signedKg(_ value: Double) -> String {
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
        if value < 0 { return "-\(formatted) kg" }
        if value > 0 { return "+\(formatted) kg" }
        return "0.0 kg"
    }
}

struct SummaryMetricCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppScreenMetrics.cardInteriorPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                    .fill(LyneqoTheme.card)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
