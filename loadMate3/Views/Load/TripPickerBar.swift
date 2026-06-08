import SwiftUI
import SwiftData

struct TripPickerBar: View {
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let trips: [Trip]
    let activeTrip: Trip?

    @Binding var showAddTrip: Bool
    @Binding var tripPendingRename: Trip?
    @Binding var tripRenameField: String
    var onOpenTripNotes: ((Trip) -> Void)? = nil

    private var canDeleteActiveTrip: Bool {
        trips.count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: AppScreenMetrics.smallSpacing) {
                AppSectionHeading("Trip")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let trip = activeTrip, let onOpenTripNotes {
                    TripNotesToolbarButton(profile: profile, trip: trip) {
                        onOpenTripNotes(trip)
                    }
                }

                Menu {
                    Button {
                        showAddTrip = true
                    } label: {
                        Label("New trip", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add trip")
                .pointerHelp("New trip")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppScreenMetrics.smallSpacing) {
                    ForEach(trips) { trip in
                        tripChip(trip)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
        .padding(.top, AppScreenMetrics.smallSpacing)
        .padding(.bottom, AppScreenMetrics.controlSpacing)
    }

    @ViewBuilder
    private func tripChip(_ trip: Trip) -> some View {
        let isActive = trip.id == activeTrip?.id

        Button {
            TripStore.setActive(trip, on: profile, in: modelContext)
        } label: {
            HStack(spacing: 6) {
                Text(trip.name)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
                if trip.hasLoadingNotes(for: profile.kind) {
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.9) : Color.accentColor)
                        .frame(width: 6, height: 6)
                }
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onOpenTripNotes {
                Button {
                    onOpenTripNotes(trip)
                } label: {
                    Label("Trip notes", systemImage: "note.text")
                }
            }

            if isActive {
                Button {
                    tripPendingRename = trip
                    tripRenameField = trip.name
                } label: {
                    Label("Rename trip", systemImage: "pencil")
                }

                if canDeleteActiveTrip {
                    Button(role: .destructive) {
                        TripStore.deleteTrip(trip, from: profile, in: modelContext)
                    } label: {
                        Label("Delete trip", systemImage: "trash")
                    }
                }
            }
        }
        .accessibilityLabel("\(trip.name)\(isActive ? ", selected" : "")")
        .accessibilityHint(isActive ? "Long press for rename or delete" : "Double tap to switch to this trip")
    }
}

// MARK: - Add trip sheet

struct AddTripSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var name: String
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppLabeledTextField(
                        "Trip name",
                        placeholder: "e.g., Beach, Grandkids, Europe",
                        text: $name
                    )

                    AppPrimaryButton("Create trip") {
                        onAdd()
                    }
                    .padding(.top, AppScreenMetrics.tinySpacing)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .appScreenBackground()
            .navigationTitle("New trip")
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
