import SwiftUI

struct LocationZonePickerSheet: View {
    let vehicleKind: VehicleKind
    let itemTitle: String
    let selectedZone: LoadZone
    let onSelect: (LoadZone) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(LoadZone.pickerZones(for: vehicleKind)) { zone in
                    Button {
                        onSelect(zone)
                        dismiss()
                    } label: {
                        HStack(spacing: AppScreenMetrics.controlSpacing) {
                            Circle()
                                .fill(zone.chipAccentColor)
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(zone.locationBadgeTitle(for: vehicleKind))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                Text(zone.locationImpactHint(for: vehicleKind))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                            }

                            Spacer(minLength: 0)

                            if selectedZone == zone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(zone.locationBadgeTitle(for: vehicleKind))
                    .accessibilityAddTraits(selectedZone == zone ? [.isSelected] : [])
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(itemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
