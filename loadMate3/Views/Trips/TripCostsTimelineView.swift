import SwiftData
import SwiftUI

enum TripRecordsSection: String, CaseIterable, Identifiable {
    case trips = "Trips"
    case costs = "Costs"

    var id: String { rawValue }
}

struct TripCostsTimelineView: View {
    let records: [TripRecord]
    var onAddCost: (TripRecord) -> Void

    @State private var expandedIDs: Set<UUID> = []
    @State private var showsAllCostYears = false

    private var timeline: [TripRecord] {
        TripRecordSupport.timelineSorted(records)
    }

    private var years: [TripRecordSupport.AnnualCostYear] {
        TripRecordSupport.annualCosts(for: records)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            if !years.isEmpty {
                yearlyCostsSection
            }

            AppSettingsSection(
                "Cost timeline",
                caption: "Tap a trip to open it. Expand a row to see Fuel, Site and other costs."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, record in
                        TripCostTimelineRow(
                            record: record,
                            isLast: index == timeline.count - 1,
                            isExpanded: expandedIDs.contains(record.id),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedIDs.contains(record.id) {
                                        expandedIDs.remove(record.id)
                                    } else {
                                        expandedIDs.insert(record.id)
                                    }
                                }
                            },
                            onAddCost: { onAddCost(record) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var yearlyCostsSection: some View {
        AppSettingsSection(
            "Yearly costs",
            caption: "Calendar-year totals from recorded trip costs."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                ForEach(visibleYears) { year in
                    HStack(alignment: .firstTextBaseline, spacing: AppScreenMetrics.controlSpacing) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(year.year))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Text(year.detail)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                        Spacer(minLength: 8)
                        Text(TripRecordMoney.format(year.totalMinorUnits, currencyCode: year.currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }
                }

                if years.count > 2 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsAllCostYears.toggle()
                        }
                    } label: {
                        Label(
                            showsAllCostYears ? "Show fewer years" : "See all \(years.count) years",
                            systemImage: showsAllCostYears ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.purple)
                }
            }
        }
    }

    private var visibleYears: [TripRecordSupport.AnnualCostYear] {
        guard !showsAllCostYears, years.count > 2 else { return years }
        let currentYear = Calendar.current.component(.year, from: Date())
        let upcoming = years.filter { $0.year >= currentYear }
        guard upcoming.count >= 2 else { return Array(years.prefix(2)) }
        return Array(upcoming.prefix(2))
    }
}

private struct TripCostTimelineRow: View {
    let record: TripRecord
    let isLast: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAddCost: () -> Void

    private var totals: TripRecordTotals {
        TripRecordSupport.totals(for: record)
    }

    private var phase: TripRecordPhase {
        TripRecordSupport.phase(for: record)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(markerColor)
                    .frame(width: 12, height: 12)
                    .frame(width: 16, height: 16)
                if !isLast {
                    Rectangle()
                        .fill(LyneqoTheme.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 8) {
                NavigationLink {
                    TripRecordDetailView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(record.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Spacer(minLength: 8)
                            Text(costCaption)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(totals.hasAnyCost ? Color.primary : AppColors.purple)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(TripRecordSupport.dateRangeText(startDate: record.startDate, endDate: record.endDate))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                            if let destination = TripRecordSupport.principalDestination(for: record) {
                                Text(destination)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(record.name), \(costCaption)")

                Button(action: onToggle) {
                    Label(
                        isExpanded ? "Hide costs" : "Show costs",
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.purple)
                .accessibilityHint("Shows the itemised costs for this trip")

                if isExpanded {
                    costDetails
                }
            }
            .padding(.bottom, isLast ? 0 : AppScreenMetrics.sectionSpacing)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var costDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if totals.summaryRows.isEmpty {
                Text("No costs recorded yet.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                ForEach(totals.summaryRows, id: \.title) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.title)
                            .font(.caption)
                            .foregroundStyle(Color.primary)
                        Spacer(minLength: 8)
                        Text(TripRecordMoney.format(row.minorUnits, currencyCode: record.currencyCode))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Trip total")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(TripRecordMoney.format(totals.grandMinorUnits, currencyCode: record.currencyCode))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.primary)
            }

            Button(action: onAddCost) {
                Label(totals.hasAnyCost ? "Add another cost" : "Add cost", systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.purple)
        }
        .padding(AppScreenMetrics.controlSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                .fill(LyneqoTheme.softTeal.opacity(0.35))
        }
    }

    private var costCaption: String {
        if totals.hasAnyCost {
            return TripRecordMoney.format(totals.grandMinorUnits, currencyCode: record.currencyCode)
        }
        return "Add cost"
    }

    private var markerColor: Color {
        switch phase {
        case .completed: return AppColors.green
        case .current: return AppColors.teal
        case .upcoming: return Color.secondary.opacity(0.85)
        }
    }
}
