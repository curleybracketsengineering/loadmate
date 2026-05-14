import SwiftUI
import SwiftData

struct LocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LoadedItem.loadedAt)]) private var loadedItems: [LoadedItem]
    @Query private var configs: [SetupConfig]

    @StateObject private var viewModel = LocationViewModel()

    private var setupConfig: SetupConfig? { configs.first }

    private var estimatedTowBarKg: Double? {
        guard let config = setupConfig else { return nil }
        return WeightCalculator.summary(config: config, loadedItems: loadedItems).estimatedNoseWeightKg
    }

    var body: some View {
        NavigationStack {
            Group {
                if loadedItems.isEmpty {
                    LocationEmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                            AppSectionHeading(
                                "Assign locations",
                                caption: "Choose where each loaded item sits on the caravan. This affects nose weight estimates."
                            )

                            towBarEstimateCard

                            zoneLegend

                            VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                                ForEach(loadedItems) { loaded in
                                    LocationItemZoneCard(
                                        title: title(for: loaded),
                                        weightLine: weightLine(for: loaded),
                                        selectedZone: loaded.zone,
                                        onSelectZone: { zone in
                                            viewModel.updateZone(for: loaded, to: zone, in: modelContext)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.top, AppScreenMetrics.verticalScreenPadding)
                        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(Color(.systemGroupedBackground))
            .appPrincipalTabTitle("Locations")
        }
    }

    private var towBarEstimateCard: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Estimated tow bar weight")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)

            if let kg = estimatedTowBarKg {
                Text(Formatters.kg(kg))
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var zoneLegend: some View {
        HStack(spacing: AppScreenMetrics.smallSpacing) {
            ForEach(LoadZone.pickerZones) { zone in
                HStack(spacing: AppScreenMetrics.tinySpacing) {
                    Circle()
                        .fill(zone.chipAccentColor)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)

                    Text(zone.shortLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel("Zone legend: \(LoadZone.pickerZones.map(\.shortLabel).joined(separator: ", "))")
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

// MARK: - Empty state

private struct LocationEmptyStateView: View {
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
        }
        .padding(.vertical, AppScreenMetrics.sectionSpacingLoose)
    }
}

// MARK: - Item card

private struct LocationItemZoneCard: View {
    let title: String
    let weightLine: String
    let selectedZone: LoadZone
    let onSelectZone: (LoadZone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: AppScreenMetrics.smallSpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(weightLine)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }

            HStack(spacing: AppScreenMetrics.controlSpacing) {
                ForEach(LoadZone.pickerZones) { zone in
                    zoneChip(for: zone)
                }
            }
        }
        .padding(.vertical, AppScreenMetrics.smallSpacing)
        .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func zoneChip(for zone: LoadZone) -> some View {
        let selected = selectedZone == zone

        return Button {
            onSelectZone(zone)
        } label: {
            Text(zone.shortLabel)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? zone.chipAccentColor : zone.chipAccentColor.opacity(0.28))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Color.primary : Color.clear, lineWidth: selected ? 2 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(zone.title) zone")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Zone labels & colors (Locations UI)

extension LoadZone {
    /// Zones shown as FB / F / M / B / BR chips (excludes `unassigned`).
    static var pickerZones: [LoadZone] {
        [.frontLocker, .front, .middle, .rear, .bikeRack]
    }

    var shortLabel: String {
        switch self {
        case .frontLocker: return "FB"
        case .front: return "F"
        case .middle: return "M"
        case .rear: return "B"
        case .bikeRack: return "BR"
        case .unassigned: return "—"
        }
    }

    /// Matches legend / chip hues from design (FB blue … BR green).
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
