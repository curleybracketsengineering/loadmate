import SwiftUI
import SwiftData

struct LoadSummaryStepView: View {
    let profile: VehicleProfile
    let trip: Trip?
    let caravanSummary: WeightSummary?
    let motorhomeSummary: MotorhomeWeightSummary?
    let loadedItems: [LoadedItem]
    var showsNoseWeightInline: Bool = true

    private var isSafe: Bool {
        caravanSummary?.isOverallSafe ?? motorhomeSummary?.isOverallSafe ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            statusBanner

            weightOverviewCard

            if showsNoseWeightInline, profile.kind == .caravan, let summary = caravanSummary {
                noseWeightSection(summary: summary)
                insightsSection(caravan: summary, motorhome: nil)
            } else if let summary = motorhomeSummary {
                insightsSection(caravan: nil, motorhome: summary)
            }
        }
    }

    private var statusBanner: some View {
        HStack {
            Image(systemName: isSafe ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(isSafe ? "SAFE — You're within all safety limits." : "CHECK — Review limits before travel.")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(isSafe ? Color.accentColor : AppColors.orange)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private var weightOverviewCard: some View {
        let current = caravanSummary?.totalWeightKg ?? motorhomeSummary?.totalWeightKg ?? 0
        let limit = profile.mtplmKg
        let fraction = limit > 0 ? min(current / limit, 1) : 0

        return VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Current Weight")
                .font(.headline.weight(.semibold))
            Text(Formatters.kg(current))
                .font(.title.weight(.bold))
                .foregroundStyle(Color.accentColor)
            if limit > 0 {
                Text("of \(Formatters.kg(limit)) MTPLM")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(Color.accentColor).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private func noseWeightSection(summary: WeightSummary) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Nose Weight")
                .font(.headline.weight(.semibold))
            Text(Formatters.kg(summary.estimatedNoseWeightKg))
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text("Estimated")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)

            let zoneBounds = summary.noseGaugeZoneBounds(profile: profile)
            NoseWeightSafeZoneGauge(
                zoneLowKg: zoneBounds.low,
                zoneHighKg: zoneBounds.high,
                carMaxTowBallKg: profile.effectiveMaxTowBallKg,
                estimatedNoseKg: summary.estimatedNoseWeightKg,
                showsTitle: false
            )
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private func insightsSection(caravan: WeightSummary?, motorhome: MotorhomeWeightSummary?) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Insights")
                .font(.headline.weight(.semibold))

            if let caravan {
                insightRow("Tow ball weight within target range.", positive: !caravan.isNoseBelowRecommended && !caravan.isNoseAboveRecommended)
                let zoneWeights = LocationZoneWeights.totals(for: loadedItems, kind: .caravan, profile: profile)
                if let heaviest = zoneWeights.max(by: { $0.value < $1.value }) {
                    insightRow("\(heaviest.key.locationBadgeTitle(for: .caravan)) zone is the heaviest (\(Formatters.kg(heaviest.value))).", positive: true)
                }
                insightRow("\(Formatters.kg(caravan.availableWeightKg)) payload remaining.", positive: caravan.availableWeightKg > 0)
            }

            if let motorhome {
                insightRow("Gross weight within MAM.", positive: !motorhome.isOverMAM)
                insightRow("Front axle within limit.", positive: !motorhome.isOverFrontAxle)
                insightRow("Rear axle within limit.", positive: !motorhome.isOverRearAxle)
                insightRow("\(Formatters.kg(motorhome.availableGrossKg)) payload remaining.", positive: motorhome.availableGrossKg > 0)
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private func insightRow(_ text: String, positive: Bool) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: positive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(positive ? AppColors.green : AppColors.orange)
        }
    }
}
