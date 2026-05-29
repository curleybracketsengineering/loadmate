import SwiftUI

/// iPad placement illustration with live zone weight chips (asset-backed cutaway).
struct VehicleCutawayPadView: View {
    let vehicleKind: VehicleKind
    let zoneWeightsKg: [LoadZone: Double]
    var overLimitZones: Set<LoadZone> = []

    private var displayZones: [LoadZone] {
        vehicleKind.padZoneDisplayOrder
    }

    var body: some View {
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            zoneChipRow
            Image(vehicleKind.padCutawayAssetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(vehicleKind == .motorhome ? "Motorhome load zones" : "Caravan load zones")
        }
    }

    private var zoneChipRow: some View {
        HStack(spacing: AppScreenMetrics.controlSpacing) {
            ForEach(displayZones, id: \.self) { zone in
                PadZoneChip(
                    title: zone.padChipTitle(for: vehicleKind),
                    weightKg: zoneWeightsKg[zone] ?? 0,
                    accent: zone.chipAccentColor,
                    isOverLimit: overLimitZones.contains(zone)
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct PadZoneChip: View {
    let title: String
    let weightKg: Double
    let accent: Color
    let isOverLimit: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(Formatters.kg(weightKg))
                .font(.caption.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(isOverLimit ? AppColors.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOverLimit ? AppColors.red : accent.opacity(0.35), lineWidth: isOverLimit ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Formatters.kg(weightKg))")
    }
}
