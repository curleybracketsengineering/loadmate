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
                VStack(spacing: 3) {
                    Text(zone.locationBadgeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(zone.chipAccentColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(Formatters.kg(zoneWeightsKg[zone] ?? 0))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(zone.chipAccentColor.opacity(0.32))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(zone.chipAccentColor.opacity(0.55), lineWidth: 1)
                }
                .accessibilityLabel("\(zone.locationBadgeTitle) zone, \(Formatters.kg(zoneWeightsKg[zone] ?? 0))")
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
                Text("Increases")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.blue)
                Spacer()
                Text("Neutral")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LoadZone.middle.chipAccentColor)
                Spacer()
                Text("Decreases")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.green)
            }
        }
        .accessibilityLabel("Nose weight impact scale. Front zones increase nose weight; rear zones decrease it.")
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
