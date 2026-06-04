import SwiftUI
import SwiftData

/// iPad placement column: cutaway graphic and assign-items list.
struct PlacementPadPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LoadedItem.loadedAt)]) private var allLoadedItems: [LoadedItem]
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = LocationViewModel()
    @State private var zonePickerItem: LoadedItem?
    @State private var showLocationsHelp = false

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: appStates.first)
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
        .alert("About locations", isPresented: $showLocationsHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(locationsHelpMessage)
        }
    }

    @ViewBuilder
    private func placementContent(profile: VehicleProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                HStack {
                    Text("Assign locations")
                        .font(.title3.weight(.semibold))
                    Button {
                        showLocationsHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About locations")
                    .pointerHelp("Help")
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

                assignItemsList
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.vertical, AppScreenMetrics.verticalScreenPadding)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var assignItemsList: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Loaded items")
                .font(.headline)

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
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private var padEmptyState: some View {
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            Image(systemName: "arrow.left")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(Color.secondary)
            Text("Load items on the left")
                .font(.headline)
            Text("Add items to this trip, then assign each one to a zone here.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppScreenMetrics.sectionSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var locationsHelpMessage: String {
        if activeProfile?.kind == .motorhome {
            return "Cab is ahead of the front axle; Middle between the axles; Rear above the rear; Boot and bike rack behind the rear. Stay within plated axle and garage limits."
        }
        return "Where you place each item shifts estimated tow ball (nose) weight. Front zones tend to increase it; rear zones tend to decrease it."
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
