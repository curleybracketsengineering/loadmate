import SwiftUI
import SwiftData

struct LocationView: View {
    var onNavigateToLoad: (() -> Void)?

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

    private var loadedItems: [LoadedItem] {
        VehicleProfileStore.loadedItems(for: activeProfile, from: allLoadedItems)
    }

    private var caravanSummary: WeightSummary? {
        guard let profile = activeProfile, profile.kind == .caravan else { return nil }
        return WeightCalculator.summary(profile: profile, loadedItems: loadedItems)
    }

    private var motorhomeSummary: MotorhomeWeightSummary? {
        guard let profile = activeProfile, profile.kind == .motorhome else { return nil }
        return MotorhomeWeightCalculator.summary(profile: profile, loadedItems: loadedItems)
    }

    private var zoneWeightsKg: [LoadZone: Double] {
        LocationZoneWeights.totals(for: loadedItems, kind: activeProfile?.kind ?? .caravan)
    }

    var body: some View {
        NavigationStack {
            Group {
                if loadedItems.isEmpty {
                    LocationEmptyStateView(onAddItems: onNavigateToLoad)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                                assignLocationsHeader

                                if let profile = activeProfile {
                                    weightEstimateCard(profile: profile)

                                    CaravanPositionMapView(
                                        vehicleKind: profile.kind,
                                        zoneWeightsKg: zoneWeightsKg
                                    )
                                }

                                assignItemsSection
                            }
                            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                            .padding(.top, AppScreenMetrics.verticalScreenPadding)
                            .padding(.bottom, 88)
                        }
                        .scrollDismissesKeyboard(.interactively)

                        AppFloatingAddButton(accessibilityLabel: "Add items on Load tab") {
                            onNavigateToLoad?()
                        }
                        .padding(.trailing, AppScreenMetrics.horizontalPadding)
                        .padding(.bottom, AppScreenMetrics.smallSpacing)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .appPrincipalTabTitle("Locations")
            .sheet(item: $zonePickerItem) { loaded in
                LocationZonePickerSheet(
                    vehicleKind: activeProfile?.kind ?? .caravan,
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
    }

    private var locationsHelpMessage: String {
        if activeProfile?.kind == .motorhome {
            return "Front is above the front axle; Back above the rear; Garage behind the rear. Stay within plated axle and garage limits."
        }
        return "Where you place each item shifts estimated tow bar (nose) weight. Front zones tend to increase it; rear zones tend to decrease it. Stay within your car’s tow ball limit."
    }

    private var assignLocationsCaption: String {
        if activeProfile?.kind == .motorhome {
            return "Choose where each loaded item sits: Driver, Front, Central, Back, or Garage."
        }
        return "Choose where each loaded item sits on the caravan. This affects nose weight estimates."
    }

    // MARK: - Sections

    private var assignLocationsHeader: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
            AppSectionHeading("Assign locations", caption: assignLocationsCaption)

            Button {
                showLocationsHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                    .accessibilityLabel("About locations")
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func weightEstimateCard(profile: VehicleProfile) -> some View {
        switch profile.kind {
        case .caravan:
            if let summary = caravanSummary {
                towBarEstimateCard(summary: summary, profile: profile)
            }
        case .motorhome:
            if let summary = motorhomeSummary {
                motorhomeAxleEstimateCard(summary: summary, profile: profile)
            }
        }
    }

    private var assignItemsSection: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Assign items to locations")
                .font(.headline)
                .foregroundStyle(Color.primary)

            VStack(spacing: 0) {
                ForEach(Array(loadedItems.enumerated()), id: \.element.id) { index, loaded in
                    LocationItemRow(
                        title: title(for: loaded),
                        weightLine: weightLine(for: loaded),
                        zone: loaded.zone,
                        vehicleKind: activeProfile?.kind ?? .caravan,
                        onTap: { zonePickerItem = loaded }
                    )

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

    private func towBarEstimateCard(summary: WeightSummary, profile: VehicleProfile) -> some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                Text("Estimated Tow Bar Weight")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)

                Text(Formatters.kg(summary.estimatedNoseWeightKg))
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(summary.isOverTowBallLimit ? AppColors.red : Color.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            TowBarWeightStatusBadge(summary: summary, profile: profile)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func motorhomeAxleEstimateCard(summary: MotorhomeWeightSummary, profile: VehicleProfile) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            Text("Estimated axle loads")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)

            HStack(spacing: AppScreenMetrics.sectionSpacing) {
                axleColumn(
                    title: "Front",
                    kg: summary.estimatedFrontAxleKg,
                    isOver: summary.isOverFrontAxle
                )
                axleColumn(
                    title: "Rear",
                    kg: summary.estimatedRearAxleKg,
                    isOver: summary.isOverRearAxle
                )
            }

            if profile.monitorsGarageLimit {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Garage load")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSupporting)
                        Text(Formatters.kg(summary.garageLoadedKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(summary.isOverGarageLimit ? AppColors.red : Color.primary)
                    }
                    Spacer()
                    Text("max \(Formatters.kg(profile.maxGarageKg))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }
            } else if summary.garageLoadedKg > 0 {
                Text("Garage zone: \(Formatters.kg(summary.garageLoadedKg)) — set a max in Settings to monitor")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func axleColumn(title: String, kg: Double, isOver: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSupporting)
            Text(Formatters.kg(kg))
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(isOver ? AppColors.red : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

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

// MARK: - Empty state

private struct LocationEmptyStateView: View {
    var onAddItems: (() -> Void)?

    var body: some View {
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: AppScreenMetrics.heroIconSize, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.45))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("Nothing loaded yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primary)

            Text("Use the Load tab to add items, then assign each one to a zone here.")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppScreenMetrics.sectionSpacingLoose)

            if onAddItems != nil {
                Button("Go to Load") {
                    onAddItems?()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, AppScreenMetrics.smallSpacing)
            }
        }
        .padding(.vertical, AppScreenMetrics.sectionSpacingLoose)
    }
}

// MARK: - Item row

private struct LocationItemRow: View {
    let title: String
    let weightLine: String
    let zone: LoadZone
    let vehicleKind: VehicleKind
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)

                    Text(weightLine)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }

                Spacer(minLength: 0)

                LocationZoneBadge(zone: zone, vehicleKind: vehicleKind)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens zone picker")
    }
}

private struct LocationZoneBadge: View {
    let zone: LoadZone
    let vehicleKind: VehicleKind

    var body: some View {
        if zone == .unassigned {
            Text("Assign")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSupporting)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                )
        } else {
            Text(zone.locationBadgeTitle(for: vehicleKind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(zone.chipAccentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(zone.chipAccentColor.opacity(0.14))
                )
        }
    }
}
