import SwiftUI
import SwiftData

struct LocationView: View {
    var onNavigateToLoad: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LoadedItem.loadedAt)]) private var loadedItems: [LoadedItem]
    @Query private var configs: [SetupConfig]

    @StateObject private var viewModel = LocationViewModel()
    @State private var zonePickerItem: LoadedItem?
    @State private var showLocationsHelp = false

    private var setupConfig: SetupConfig? { configs.first }

    private var weightSummary: WeightSummary? {
        guard let config = setupConfig else { return nil }
        return WeightCalculator.summary(config: config, loadedItems: loadedItems)
    }

    private var zoneWeightsKg: [LoadZone: Double] {
        LocationZoneWeights.totals(for: loadedItems)
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

                                if let summary = weightSummary, let config = setupConfig {
                                    towBarEstimateCard(summary: summary, config: config)
                                }

                                CaravanPositionMapView(zoneWeightsKg: zoneWeightsKg)

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
                Text("Where you place each item shifts estimated tow bar (nose) weight. Front zones tend to increase it; rear zones tend to decrease it. Stay within your car’s tow ball limit.")
            }
        }
    }

    // MARK: - Sections

    private var assignLocationsHeader: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
            AppSectionHeading(
                "Assign locations",
                caption: "Choose where each loaded item sits on the caravan. This affects nose weight estimates."
            )

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

    private func towBarEstimateCard(summary: WeightSummary, config: SetupConfig) -> some View {
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

            TowBarWeightStatusBadge(summary: summary, config: config)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
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

                LocationZoneBadge(zone: zone)

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
            Text(zone.locationBadgeTitle)
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

// MARK: - Zone labels & colors (Locations UI)

extension LoadZone {
    /// Zones shown on the map and in the zone picker (excludes `unassigned`).
    static var pickerZones: [LoadZone] {
        [.frontLocker, .front, .middle, .rear, .bikeRack]
    }

    /// Full zone name for map labels and list badges (e.g. “Locker”, “Bike”).
    var locationBadgeTitle: String {
        switch self {
        case .frontLocker: return "Locker"
        case .front: return "Front"
        case .middle: return "Middle"
        case .rear: return "Rear"
        case .bikeRack: return "Bike"
        case .unassigned: return "Unassigned"
        }
    }

    var noseImpactHint: String {
        switch self {
        case .frontLocker: return "Increases nose weight most"
        case .front: return "Increases nose weight"
        case .middle: return "Neutral impact on nose weight"
        case .rear: return "Decreases nose weight"
        case .bikeRack: return "Decreases nose weight most"
        case .unassigned: return ""
        }
    }

    /// Matches map / badge hues by zone position (front … bike rack).
    var chipAccentColor: Color {
        switch self {
        case .frontLocker: AppColors.blue
        case .front: Color(red: 0.58, green: 0.29, blue: 0.91)
        case .middle: Color(red: 1.0, green: 0.27, blue: 0.45)
        case .rear: AppColors.orange
        case .bikeRack: AppColors.green
        case .unassigned: Color.secondary
        }
    }
}
