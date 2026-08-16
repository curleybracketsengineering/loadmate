import SwiftUI
import SwiftData

/// iPad placement column: cutaway graphic and assign-items list.
struct PlacementPadPanel: View {
    enum Layout {
        /// Vertical scroll: map then list (legacy).
        case stacked
        /// Side-by-side: cutaway left, assigned items right (Load Planner tab).
        case split
    }

    var layout: Layout = .stacked
    var onAddItems: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LoadedItem.loadedAt)]) private var allLoadedItems: [LoadedItem]
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = LocationViewModel()
    @State private var zonePickerItem: LoadedItem?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var activeTrip: Trip? {
        TripStore.activeTrip(for: activeProfile)
    }

    private var loadedItems: [LoadedItem] {
        TripStore.loadedItems(for: activeTrip, from: allLoadedItems)
    }

    private var zoneWeightsKg: [LoadZone: Double] {
        LocationZoneWeights.totals(for: loadedItems, kind: activeProfile?.kind ?? .caravan, profile: activeProfile)
    }

    private var motorhomeSummary: MotorhomeWeightSummary? {
        guard let profile = activeProfile, profile.kind == .motorhome else { return nil }
        return MotorhomeWeightCalculator.summary(profile: profile, loadedItems: loadedItems, trip: activeTrip)
    }

    private var overLimitZones: Set<LoadZone> {
        guard let profile = activeProfile, profile.kind == .motorhome, let summary = motorhomeSummary else {
            return []
        }
        var zones = Set<LoadZone>()
        if summary.isOverGarageLimit { zones.insert(.garage) }
        if summary.isOverRearAxle { zones.insert(.back) }
        if summary.isOverFrontAxle { zones.insert(.driver) }
        return zones
    }

    var body: some View {
        Group {
            if let profile = activeProfile {
                if loadedItems.isEmpty {
                    padEmptyState
                } else {
                    placementContent(profile: profile)
                }
            } else {
                ContentUnavailableView(
                    "No vehicle",
                    systemImage: "car.fill",
                    description: Text("Add a vehicle in Settings.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $zonePickerItem) { loaded in
            LocationZonePickerSheet(
                vehicleKind: activeProfile?.kind ?? .caravan,
                profile: activeProfile,
                itemTitle: title(for: loaded),
                selectedZone: loaded.zone,
                onSelect: { zone in
                    viewModel.updateZone(for: loaded, to: zone, in: modelContext)
                }
            )
        }
    }

    @ViewBuilder
    private func placementContent(profile: VehicleProfile) -> some View {
        switch layout {
        case .stacked:
            stackedPlacementContent(profile: profile)
        case .split:
            splitPlacementContent(profile: profile)
        }
    }

    private func stackedPlacementContent(profile: VehicleProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                VehicleCutawayPadView(
                    profile: profile,
                    zoneWeightsKg: zoneWeightsKg,
                    overLimitZones: overLimitZones,
                    onDropAssign: { zone, loadedItemID in
                        guard let loaded = loadedItems.first(where: { $0.id == loadedItemID }) else { return }
                        viewModel.updateZone(for: loaded, to: zone, in: modelContext)
                    }
                )

                assignItemsList
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.vertical, AppScreenMetrics.verticalScreenPadding)
            .frame(maxWidth: .infinity)
        }
        .loadPlannerScrollPanel()
    }

    private func splitPlacementContent(profile: VehicleProfile) -> some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    if profile.kind == .caravan, let summary = caravanSummary {
                        noseEffectBanner(kg: summary.estimatedNoseWeightKg)
                    } else if profile.kind == .motorhome, let summary = motorhomeSummary {
                        noseEffectBanner(kg: summary.towBarLoadKg, label: "Tow bar load")
                    }

                    VehicleCutawayPadView(
                        profile: profile,
                        zoneWeightsKg: zoneWeightsKg,
                        overLimitZones: overLimitZones,
                        onDropAssign: { zone, loadedItemID in
                            guard let loaded = loadedItems.first(where: { $0.id == loadedItemID }) else { return }
                            viewModel.updateZone(for: loaded, to: zone, in: modelContext)
                        }
                    )
                }
                .padding(.vertical, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                .frame(maxWidth: .infinity)
            }
            .loadPlannerScrollPanel()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                Text("Assigned Items")
                    .font(.headline.weight(.semibold))
                    .padding(.top, AppScreenMetrics.verticalScreenPadding)
                ScrollView {
                    assignItemsList
                        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                }
                .loadPlannerScrollPanel()
            }
            .frame(width: 320)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, PadContentLayout.horizontalGutter)
        .frame(maxHeight: .infinity)
    }

    private var caravanSummary: WeightSummary? {
        guard let profile = activeProfile, profile.kind == .caravan else { return nil }
        return WeightCalculator.summary(profile: profile, loadedItems: loadedItems)
    }

    private func noseEffectBanner(kg: Double, label: String = "Total Nose Effect") -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSupporting)
            Spacer()
            Text(Formatters.kg(kg))
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private var assignItemsList: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            if layout == .stacked {
                Text("Loaded items")
                    .font(.headline)
            }

            VStack(spacing: 0) {
                ForEach(Array(loadedItems.enumerated()), id: \.element.id) { index, loaded in
                    PlacementPadItemRow(
                        title: title(for: loaded),
                        weightLine: weightLine(for: loaded),
                        zone: loaded.zone,
                        vehicleKind: activeProfile?.kind ?? .caravan,
                        onTap: { zonePickerItem = loaded }
                    )
                    .draggable(LoadedItemDragPayload(loadedItemID: loaded.id))

                    if index < loadedItems.count - 1 {
                        Divider()
                            .padding(.leading, AppScreenMetrics.cardInteriorPadding)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .fill(LyneqoTheme.card)
            )
        }
    }

    private var padEmptyState: some View {
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            Image(systemName: "shippingbox")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(Color.secondary)
            Text("No items loaded")
                .font(.headline)
            Text("Add items on the Items tab, then assign each one to a zone here.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppScreenMetrics.sectionSpacing)
            if let onAddItems {
                AppPrimaryButton("Go to Items", systemImage: "arrow.left") {
                    onAddItems()
                }
                .padding(.horizontal, AppScreenMetrics.sectionSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func title(for loaded: LoadedItem) -> String {
        let name = loaded.item?.name ?? "Unknown item"
        guard let itemId = loaded.item?.id else { return name }
        let sameItem = loadedItems.filter { $0.item?.id == itemId }.sorted { $0.loadedAt < $1.loadedAt }
        guard sameItem.count > 1, let index = sameItem.firstIndex(where: { $0.id == loaded.id }) else {
            return name
        }
        return "\(name) (\(index + 1) of \(sameItem.count))"
    }

    private func weightLine(for loaded: LoadedItem) -> String {
        let unitKg = loaded.item?.weightKg ?? 0
        let totalKg = unitKg * Double(max(loaded.quantity, 0))
        return Formatters.kg(totalKg)
    }
}

private struct PlacementPadItemRow: View {
    let title: String
    let weightLine: String
    let zone: LoadZone
    let vehicleKind: VehicleKind
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: AppScreenMetrics.controlSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(weightLine)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            Spacer(minLength: 0)
            Text(zone.padChipTitle(for: vehicleKind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(zone.chipAccentColor(for: vehicleKind))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(zone.chipAccentColor(for: vehicleKind).opacity(0.14)))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
