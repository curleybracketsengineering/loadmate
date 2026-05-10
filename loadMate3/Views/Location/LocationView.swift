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
                        VStack(alignment: .leading, spacing: 20) {
                            assignHeader

                            AppSectionDivider()

                            towBarEstimateBlock

                            AppSectionDivider()

                            zoneLegend

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
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.vertical, 16)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var assignHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assign Locations")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text(itemsLoadedSubtitle)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var itemsLoadedSubtitle: String {
        let n = loadedItems.count
        let noun = n == 1 ? "item" : "items"
        return "\(n) \(noun) loaded"
    }

    private var towBarEstimateBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estimated tow bar weight")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            if let kg = estimatedTowBarKg {
                Text(Formatters.kg(kg))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var zoneLegend: some View {
        HStack(spacing: 8) {
            ForEach(LoadZone.pickerZones) { zone in
                HStack(spacing: 6) {
                    Circle()
                        .fill(zone.chipAccentColor)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)

                    Text(zone.shortLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
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
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(AppColors.blue.opacity(0.45))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("Nothing loaded yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Use the Load tab to add items, then assign each one to a zone here.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Item card

private struct LocationItemZoneCard: View {
    let title: String
    let weightLine: String
    let selectedZone: LoadZone
    let onSelectZone: (LoadZone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text(weightLine)
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 10) {
                ForEach(LoadZone.pickerZones) { zone in
                    zoneChip(for: zone)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.inputSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(AppColors.inputBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func zoneChip(for zone: LoadZone) -> some View {
        let selected = selectedZone == zone

        return Button {
            onSelectZone(zone)
        } label: {
            Text(zone.shortLabel)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Color.white : AppColors.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? zone.chipAccentColor : zone.chipAccentColor.opacity(0.28))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.primary : Color.clear, lineWidth: selected ? 3 : 0)
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
        case .unassigned: AppColors.textTertiary
        }
    }
}
