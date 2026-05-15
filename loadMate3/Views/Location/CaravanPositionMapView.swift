import SwiftUI

/// Top-down caravan zones, nose-weight impact scale, and per-zone loaded mass.
struct CaravanPositionMapView: View {
    let zoneWeightsKg: [LoadZone: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            Text("Caravan Position Map")
                .font(.headline)
                .foregroundStyle(Color.primary)

            caravanOutline

            noseImpactScale

            zoneTotalsRow
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Caravan position map")
    }

    private var caravanOutline: some View {
        HStack(spacing: 3) {
            ForEach(LoadZone.pickerZones) { zone in
                VStack(spacing: 4) {
                    Text(zone.shortLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(zone.chipAccentColor)
                    Text(zone.locationBadgeTitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 76)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(zone.chipAccentColor.opacity(0.32))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(zone.chipAccentColor.opacity(0.55), lineWidth: 1)
                }
                .accessibilityLabel("\(zone.locationBadgeTitle) zone")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.45), lineWidth: 1.5)
        )
    }

    private var noseImpactScale: some View {
        VStack(spacing: 6) {
            LinearGradient(
                colors: [
                    AppColors.blue.opacity(0.85),
                    LoadZone.middle.chipAccentColor.opacity(0.75),
                    AppColors.green.opacity(0.85)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())

            HStack {
                Text("More Increases")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.blue)
                Spacer()
                Text("Neutral")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LoadZone.middle.chipAccentColor)
                Spacer()
                Text("More Decreases")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.green)
            }
        }
        .accessibilityLabel("Nose weight impact scale. Front zones increase nose weight; rear zones decrease it.")
    }

    private var zoneTotalsRow: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.tinySpacing) {
            ForEach(LoadZone.pickerZones) { zone in
                VStack(spacing: 3) {
                    Text(zone.shortLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(zone.chipAccentColor)
                    Text(zone.locationBadgeTitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppColors.textSupporting)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(Formatters.kg(zoneWeightsKg[zone] ?? 0))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(zone.shortLabel) \(zone.locationBadgeTitle), \(Formatters.kg(zoneWeightsKg[zone] ?? 0))")
            }
        }
    }
}

enum LocationZoneWeights {
    static func totals(for loadedItems: [LoadedItem]) -> [LoadZone: Double] {
        var totals = Dictionary(uniqueKeysWithValues: LoadZone.pickerZones.map { ($0, 0.0) })
        for loaded in loadedItems {
            guard LoadZone.pickerZones.contains(loaded.zone) else { continue }
            let mass = (loaded.item?.weightKg ?? 0) * Double(max(loaded.quantity, 0))
            totals[loaded.zone, default: 0] += mass
        }
        return totals
    }
}
