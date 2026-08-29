import SwiftData
import SwiftUI

struct TripRecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTrips: [Trip]
    @Query(sort: \TripRecord.startDate, order: .reverse) private var allRecords: [TripRecord]

    let recordID: UUID

    @State private var showEditor = false
    @State private var confirmDelete = false

    init(record: TripRecord) {
        self.recordID = record.id
    }

    private var record: TripRecord? {
        TripRecordStore.record(id: recordID, from: Array(allRecords))
    }

    var body: some View {
        Group {
            if let record {
                detailScroll(record)
            } else {
                ContentUnavailableView(
                    "Trip not found",
                    systemImage: "suitcase",
                    description: Text("This trip is no longer available.")
                )
            }
        }
        .appScreenBackground()
        .navigationTitle(record?.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(record == nil)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let record {
                TripRecordEditorView(draft: .from(record), onCancel: { showEditor = false }) { _ in
                    showEditor = false
                }
            }
        }
        .confirmationDialog("Delete this trip?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) {
                deleteRecord()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The route and costs for this trip will be removed. Loading configurations are not deleted.")
        }
    }

    private func detailScroll(_ record: TripRecord) -> some View {
        let totals = TripRecordSupport.totals(for: record)
        return ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                headerSection(record)

                if !record.stopsList.isEmpty || !record.legsList.isEmpty {
                    routeSection(record, totals: totals)
                }

                if totals.hasAnyCost {
                    costsSection(record, totals: totals)
                }

                loadingConfigurationSection(record)

                let notes = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notes.isEmpty {
                    AppSettingsSection("Notes") {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                    }
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent()
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                showEditor = true
            }
            .accessibilityAction(named: "Edit") {
                showEditor = true
            }
        }
    }

    private func headerSection(_ record: TripRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            Text(record.name)
                .font(.title2.weight(.bold))
            Text(TripRecordSupport.dateRangeText(startDate: record.startDate, endDate: record.endDate))
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
            Text(TripRecordSupport.phase(for: record).listTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.teal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routeSection(_ record: TripRecord, totals: TripRecordTotals) -> some View {
        let cards = TripRecordSupport.routeCards(from: record)
        return AppSettingsSection("Route") {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    switch card {
                    case .journey(let id, _):
                        if let leg = record.legsList.first(where: { $0.id == id }) {
                            journeyDetail(leg)
                        }
                    case .stay(let id, _, let place):
                        if let stop = record.stopsList.first(where: { $0.id == id }) {
                            stayDetail(stop, place: place, currencyCode: record.currencyCode)
                        }
                    }
                    if index < cards.count - 1 || totals.hasMileage || totals.hasTravelTime {
                        Divider()
                    }
                }

                if totals.hasMileage {
                    Text("Total \(TripRecordSupport.mileageText(totals.mileage))")
                        .font(.subheadline.weight(.semibold))
                }
                if totals.hasTravelTime {
                    Text("Total \(TripRecordSupport.travelTimeText(totals.travelMinutes))")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func journeyDetail(_ leg: TripLeg) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(leg.fromName) → \(leg.toName)")
                .font(.subheadline.weight(.semibold))
            if let travelledOn = leg.travelledOn {
                Text(Formatters.date(travelledOn))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            if let mileage = leg.mileage {
                Text(TripRecordSupport.mileageText(mileage))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            if let minutes = leg.travelMinutes {
                Text(TripRecordSupport.travelTimeText(minutes))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            let notes = leg.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
        }
    }

    private func stayDetail(_ stop: TripStop, place: String, currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let title = place.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(title.isEmpty ? "Stay" : "Stay at \(title)")
                .font(.subheadline.weight(.semibold))
            if let arrived = stop.arrivedAt {
                Text("Arrive \(Formatters.date(arrived))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            if let departed = stop.departedAt {
                Text("Depart \(Formatters.date(departed))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            if let siteCost = stop.siteCostMinorUnits {
                Text("Site \(TripRecordMoney.format(siteCost, currencyCode: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            let notes = stop.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
        }
    }

    private func costsSection(_ record: TripRecord, totals: TripRecordTotals) -> some View {
        AppSettingsSection("Costs") {
            VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                ForEach(totals.summaryRows, id: \.title) { row in
                    costRow(row.title, row.minorUnits, record.currencyCode)
                }
                costRow("Total", totals.grandMinorUnits, record.currencyCode)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func costRow(_ title: String, _ units: Int64, _ currencyCode: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(TripRecordMoney.format(units, currencyCode: currencyCode))
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func loadingConfigurationSection(_ record: TripRecord) -> some View {
        if record.loadingConfigurationID != nil {
            let trip = TripRecordStore.loadingConfiguration(id: record.loadingConfigurationID, from: Array(allTrips))
            AppSettingsSection("Loading Configuration") {
                if let trip {
                    Text(trip.name)
                        .font(.subheadline)
                } else {
                    Text("Loading configuration no longer available.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                }
            }
        }
    }

    private func deleteRecord() {
        guard let record else { return }
        TripRecordStore.delete(record, in: modelContext)
        dismiss()
    }
}
