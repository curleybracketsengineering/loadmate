import SwiftUI

/// iPad placement illustration with live zone weight chips (asset-backed cutaway).
struct VehicleCutawayPadView: View {
    let profile: VehicleProfile
    let zoneWeightsKg: [LoadZone: Double]
    var overLimitZones: Set<LoadZone> = []

    private var displayZones: [LoadZone] {
        profile.padZoneDisplayOrder
    }

    var body: some View {
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            zoneChipRow
            Image(profile.padCutawayAssetName)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(profile.kind == .motorhome ? "Motorhome load zones" : "Caravan load zones")
        }
        .frame(maxWidth: PadContentLayout.cutawayMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var zoneChipRow: some View {
        HStack(spacing: AppScreenMetrics.controlSpacing) {
            ForEach(displayZones, id: \.self) { zone in
                PadZoneChip(
                    title: zone.padChipTitle(for: profile.kind),
                    weightKg: zoneWeightsKg[zone] ?? 0,
                    accent: zone.chipAccentColor,
                    fill: zone.chipPastelFill,
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
    let fill: Color
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
                .fill(fill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOverLimit ? AppColors.red : accent.opacity(0.35), lineWidth: isOverLimit ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Formatters.kg(weightKg))")
    }
}
