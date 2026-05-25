import SwiftUI

/// Top-down vehicle zones and per-zone loaded mass.
struct CaravanPositionMapView: View {
    let vehicleKind: VehicleKind
    let zoneWeightsKg: [LoadZone: Double]

    private var zones: [LoadZone] {
        LoadZone.pickerZones(for: vehicleKind)
    }

    /// Equal zone box + axle slot so every column lines up.
    private let motorhomeZoneBoxHeight: CGFloat = 54
    private let motorhomeAxleSlotHeight: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            Text(vehicleKind == .motorhome ? "Motorhome Position Map" : "Caravan Position Map")
                .font(.headline)
                .foregroundStyle(Color.primary)

            if vehicleKind == .motorhome {
                motorhomeOutline
                Text("Wheels under Front and Back show axle positions.")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                caravanOutline
            }

            impactScale
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(vehicleKind == .motorhome ? "Motorhome position map" : "Caravan position map")
    }

    // MARK: - Motorhome

    private var motorhomeOutline: some View {
        HStack(alignment: .top, spacing: 3) {
            motorhomeColumn(zone: .driver)
            motorhomeColumn(zone: .front, showFrontAxle: true)
            motorhomeColumn(zone: .central)
            motorhomeColumn(zone: .back, showRearAxle: true)
            motorhomeColumn(zone: .garage)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.45), lineWidth: 1.5)
        )
    }

    private func motorhomeColumn(
        zone: LoadZone,
        showFrontAxle: Bool = false,
        showRearAxle: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            motorhomeZoneBox(zone)
            motorhomeAxleSlot(showFrontAxle: showFrontAxle, showRearAxle: showRearAxle)
        }
        .frame(maxWidth: .infinity)
    }

    private func motorhomeZoneBox(_ zone: LoadZone) -> some View {
        VStack(spacing: 2) {
            Text(zone.mapBadgeTitle(for: .motorhome))
                .font(.caption.weight(.semibold))
                .foregroundStyle(zone.chipAccentColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(Formatters.kg(zoneWeightsKg[zone] ?? 0))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: motorhomeZoneBoxHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(zone.chipAccentColor.opacity(0.32))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(zone.chipAccentColor.opacity(0.55), lineWidth: 1)
        }
        .accessibilityLabel("\(zone.locationBadgeTitle(for: .motorhome)) zone, \(Formatters.kg(zoneWeightsKg[zone] ?? 0))")
    }

    @ViewBuilder
    private func motorhomeAxleSlot(showFrontAxle: Bool, showRearAxle: Bool) -> some View {
        Group {
            if showFrontAxle {
                MotorhomeAxleWheelIndicator(title: "Front axle")
            } else if showRearAxle {
                MotorhomeAxleWheelIndicator(title: "Rear axle")
            } else {
                Color.clear
            }
        }
        .frame(height: motorhomeAxleSlotHeight)
    }

    // MARK: - Caravan

    private var caravanOutline: some View {
        HStack(spacing: 3) {
            ForEach(zones) { zone in
                zoneCell(zone)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.45), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func zoneCell(_ zone: LoadZone) -> some View {
        VStack(spacing: 3) {
            Text(zone.locationBadgeTitle(for: vehicleKind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(zone.chipAccentColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Text(Formatters.kg(zoneWeightsKg[zone] ?? 0))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(zone.chipAccentColor.opacity(0.32))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(zone.chipAccentColor.opacity(0.55), lineWidth: 1)
        }
        .accessibilityLabel("\(zone.locationBadgeTitle(for: vehicleKind)) zone, \(Formatters.kg(zoneWeightsKg[zone] ?? 0))")
    }

    private var impactScale: some View {
        let neutralColor = vehicleKind == .motorhome ? LoadZone.central.chipAccentColor : LoadZone.middle.chipAccentColor

        return VStack(spacing: 6) {
            LinearGradient(
                colors: [
                    AppColors.blue.opacity(0.85),
                    neutralColor.opacity(0.75),
                    AppColors.green.opacity(0.85)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())

            HStack {
                if vehicleKind == .motorhome {
                    Text("Front axle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.blue)
                    Spacer()
                    Text("Mid.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(neutralColor)
                    Spacer()
                    Text("Rear axle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.green)
                } else {
                    Text("Increases")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.blue)
                    Spacer()
                    Text("Neutral")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(neutralColor)
                    Spacer()
                    Text("Decreases")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.green)
                }
            }
        }
        .accessibilityLabel(
            vehicleKind == .motorhome
                ? "Axle load impact scale. Front is above the front axle; Back above the rear; Gar. behind the rear axle."
                : "Nose weight impact scale. Front zones increase nose weight; rear zones decrease it."
        )
    }
}

enum LocationZoneWeights {
    static func totals(for loadedItems: [LoadedItem], kind: VehicleKind) -> [LoadZone: Double] {
        let zones = LoadZone.pickerZones(for: kind)
        var totals = Dictionary(uniqueKeysWithValues: zones.map { ($0, 0.0) })
        for loaded in loadedItems {
            let zone = loaded.zone
            guard zones.contains(zone) else { continue }
            let mass = (loaded.item?.weightKg ?? 0) * Double(max(loaded.quantity, 0))
            totals[zone, default: 0] += mass
        }
        return totals
    }
}
