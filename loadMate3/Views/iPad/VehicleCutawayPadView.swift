import SwiftUI

/// iPad placement illustration with live zone weight chips (asset-backed cutaway).
struct VehicleCutawayPadView: View {
    let profile: VehicleProfile
    let zoneWeightsKg: [LoadZone: Double]
    var overLimitZones: Set<LoadZone> = []
    var onDropAssign: ((LoadZone, UUID) -> Void)? = nil

    private var displayZones: [LoadZone] {
        profile.padZoneDisplayOrder
    }

    private var dropRegions: [CutawayZoneDropLayout.Region] {
        CutawayZoneDropLayout.regions(
            assetName: profile.padCutawayAssetName,
            zones: displayZones
        )
    }

    var body: some View {
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            zoneChipRow
            cutawayWithDropTargets
        }
        .frame(maxWidth: PadContentLayout.cutawayMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var cutawayWithDropTargets: some View {
        let assetName = profile.padCutawayAssetName
        let label = profile.kind == .motorhome ? "Motorhome load zones" : "Caravan load zones"

        return Group {
            if let aspect = CutawayZoneDropLayout.imageAspectRatio(assetName: assetName),
               onDropAssign != nil,
               !dropRegions.isEmpty {
                GeometryReader { geometry in
                    let content = AspectFitGeometry.contentRect(
                        imageAspect: aspect,
                        in: geometry.size
                    )

                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .accessibilityLabel(label)

                    ForEach(dropRegions, id: \.zone) { region in
                        cutawayDropTarget(region: region, contentRect: content)
                    }
                }
                .aspectRatio(aspect, contentMode: .fit)
            } else {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(label)
            }
        }
    }

    @ViewBuilder
    private func cutawayDropTarget(
        region: CutawayZoneDropLayout.Region,
        contentRect: CGRect
    ) -> some View {
        let hit = AspectFitGeometry.pixelRect(
            normalized: region.hitRectNormalized(),
            in: contentRect
        )

        Color.clear
            .frame(width: hit.width, height: hit.height)
            .position(x: hit.midX, y: hit.midY)
            .contentShape(Rectangle())
            .accessibilityLabel("\(region.zone.locationBadgeTitle(for: profile.kind)) drop zone")
            .dropDestination(
                for: LoadedItemDragPayload.self,
                action: { payloads, _ in
                    guard let onDropAssign else { return false }
                    guard let payload = payloads.first else { return false }
                    onDropAssign(region.zone, payload.loadedItemID)
                    return true
                }
            )
    }

    private var zoneChipRow: some View {
        HStack(spacing: AppScreenMetrics.controlSpacing) {
            ForEach(displayZones, id: \.self) { zone in
                PadZoneChip(
                    title: zone.padChipTitle(for: profile.kind),
                    weightKg: zoneWeightsKg[zone] ?? 0,
                    accent: zone.chipAccentColor(for: profile.kind),
                    fill: zone.chipPastelFill(for: profile.kind),
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
