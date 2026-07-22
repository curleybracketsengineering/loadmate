import SwiftUI
import SwiftData

// MARK: - Summary helpers

extension Trip {
    func loadingNotesSummary(for kind: VehicleKind) -> String? {
        switch kind {
        case .caravan:
            var parts: [String] = []
            if measuredNoseWeightKg > 0 {
                parts.append("Nose: \(Formatters.kg(measuredNoseWeightKg))")
            }
            if towingExperience != .notSet {
                parts.append("Towing: \(towingExperience.displayName)")
            }
            if !trimmedTripNotes.isEmpty {
                parts.append(trimmedTripNotes)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .motorhome:
            return trimmedTripNotes.isEmpty ? nil : trimmedTripNotes
        }
    }
}

// MARK: - Compact toolbar button

struct TripNotesToolbarButton: View {
    let profile: VehicleProfile
    let trip: Trip
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "note.text")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())

                if trip.hasLoadingNotes(for: profile.kind) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                        .offset(x: 4, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trip notes for \(trip.name)")
        .pointerHelp("Trip notes")
    }
}

// MARK: - Notes sheet

struct TripLoadingNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    @Bindable var trip: Trip

    private static let maxNotesLength = 500
    private static let maxNoseWeightKg = 999.0
    private static let noseWeightFieldWidth: CGFloat = 92
    private static let noseWeightColumnWidth: CGFloat = 124
    private static let caravanSheetHeight: CGFloat = 356
    private static let motorhomeSheetHeight: CGFloat = 300

    @State private var selectedDetent: PresentationDetent = .height(Self.caravanSheetHeight)

    private var sheetHeight: CGFloat {
        profile.kind == .caravan ? Self.caravanSheetHeight : Self.motorhomeSheetHeight
    }

    var body: some View {
        NavigationStack {
            compactSheetBody
            .appScreenBackground()
            .navigationTitle("Trip notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents(presentationDetents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            selectedDetent = .height(sheetHeight)
        }
    }

    private var compactSheetBody: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            switch profile.kind {
            case .caravan:
                caravanFields
            case .motorhome:
                motorhomeFields
            }
        }
        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
        .padding(.top, AppScreenMetrics.smallSpacing)
        .padding(.bottom, AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var presentationDetents: Set<PresentationDetent> {
        [.height(sheetHeight), .large]
    }

    @ViewBuilder
    private var caravanFields: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text(trip.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)

            caravanNoseAndTowingRow

            tripNotesEditor(
                title: "Short notes",
                caption: "E.g. water tanks full, awning packed, last-minute changes.",
                minHeight: 80
            )
        }
    }

    private var caravanNoseAndTowingRow: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            HStack(alignment: .top, spacing: AppScreenMetrics.fieldSpacing) {
                VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                    Text("Nose weight kg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    AppBoundedNumberField(
                        value: Binding(
                            get: { trip.measuredNoseWeightKg },
                            set: { trip.measuredNoseWeightKg = min(Self.maxNoseWeightKg, max(0, $0)); save() }
                        ),
                        fractionDigitsUpperBound: 0
                    )
                    .frame(width: Self.noseWeightFieldWidth)
                }
                .frame(width: Self.noseWeightColumnWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                    Text("Towing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)

                    caravanTowingPicker
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Gauge reading at hitch height. Lyneqo Caravan & Motorhome’s estimate is for planning only.")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var caravanTowingPicker: some View {
        Picker("Towing", selection: Binding(
            get: { trip.towingExperience },
            set: { trip.towingExperience = $0; save() }
        )) {
            Text(TowingExperience.notSet.displayName).tag(TowingExperience.notSet)
            ForEach(TowingExperience.pickerCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
        .frame(minHeight: AppScreenMetrics.inputMinHeight)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var motorhomeFields: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text(trip.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)

            tripNotesEditor(
                title: "Notes",
                caption: "Record anything useful for this trip setup — handling, water levels, levelling, or last-minute changes.",
                minHeight: 80
            )
        }
    }

    private func tripNotesEditor(title: String, caption: String, minHeight: CGFloat = 120) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)

            Text(caption)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: Binding(
                get: { trip.tripNotes },
                set: { trip.tripNotes = String($0.prefix(Self.maxNotesLength)); save() }
            ))
            .frame(minHeight: minHeight)
            .padding(AppScreenMetrics.smallSpacing)
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
            }

            if trip.tripNotes.count >= Self.maxNotesLength - 20 {
                Text("\(trip.tripNotes.count)/\(Self.maxNotesLength)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)
            }
        }
    }

    private func save() {
        _ = SyncDebugSaveHelper.save(modelContext, source: "TripLoadingNotesViews.save")
    }
}
