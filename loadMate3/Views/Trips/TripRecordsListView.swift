import SwiftData
import SwiftUI

struct TripRecordsListView: View {
    @Environment(\.padTopTabBarActive) private var padTopTabBarActive
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query(sort: \TripRecord.startDate, order: .reverse) private var allRecords: [TripRecord]

    @State private var section: TripRecordsSection = .trips
    @State private var editorSession: TripRecordEditorSession?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var records: [TripRecord] {
        guard let profile = activeProfile else { return [] }
        return TripRecordStore.records(for: profile.id, from: allRecords)
    }

    private var grouped: [(TripRecordPhase, [TripRecord])] {
        TripRecordSupport.groupedForList(records)
    }

    var body: some View {
        Group {
            if activeProfile == nil {
                ContentUnavailableView(
                    "No vehicle selected",
                    systemImage: "suitcase.fill",
                    description: Text("Choose a vehicle to record trips.")
                )
            } else {
                tabbedContent
            }
        }
        .appScreenBackground()
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(padTopTabBarActive ? .inline : .large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentNewEditor()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(activeProfile == nil)
                .accessibilityLabel("New trip")
            }
        }
        .sheet(item: $editorSession) { session in
            TripRecordEditorView(draft: session.draft, onCancel: { editorSession = nil }) { _ in
                editorSession = nil
            }
        }
    }

    private var tabbedContent: some View {
        VStack(spacing: 0) {
            Picker("Trips section", selection: $section) {
                ForEach(TripRecordsSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.controlSpacing)
            .padReadableContent()

            if records.isEmpty {
                emptyState
            } else {
                switch section {
                case .trips:
                    listContent
                case .costs:
                    costsContent
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                Text("Record journeys with dates, stops, mileage and costs. You can add a loading configuration later.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)

                AppPrimaryButton("New trip", systemImage: "suitcase.fill") {
                    presentNewEditor()
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent()
        }
    }

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                Text("Dates, destinations, mileage and costs for this vehicle.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)

                AppPrimaryButton("New trip", systemImage: "suitcase.fill") {
                    presentNewEditor()
                }

                ForEach(grouped, id: \.0) { phase, items in
                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        Text(phase.listTitle)
                            .font(.headline.weight(.semibold))
                        ForEach(items) { record in
                            NavigationLink {
                                TripRecordDetailView(record: record)
                            } label: {
                                tripCard(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent()
        }
    }

    private var costsContent: some View {
        ScrollView {
            TripCostsTimelineView(records: records) { record in
                editorSession = TripRecordEditorSession(draft: .from(record))
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent()
        }
    }

    private func tripCard(_ record: TripRecord) -> some View {
        let totals = TripRecordSupport.totals(for: record)
        return HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "suitcase.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(AppColors.teal)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(TripRecordSupport.dateRangeText(startDate: record.startDate, endDate: record.endDate))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
                if let destination = TripRecordSupport.principalDestination(for: record) {
                    Text(destination)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }
                if let summary = cardSummary(totals, currencyCode: record.currencyCode) {
                    Text(summary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.primary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(record.name)
    }

    private func cardSummary(_ totals: TripRecordTotals, currencyCode: String) -> String? {
        var parts: [String] = []
        if totals.hasMileage {
            parts.append(TripRecordSupport.mileageText(totals.mileage))
        }
        if totals.hasAnyCost {
            parts.append(TripRecordMoney.format(totals.grandMinorUnits, currencyCode: currencyCode))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func presentNewEditor() {
        guard let profile = activeProfile else { return }
        editorSession = TripRecordEditorSession(draft: .blank(vehicleProfileID: profile.id))
    }
}

private struct TripRecordEditorSession: Identifiable {
    let id = UUID()
    let draft: TripRecordDraft
}
