import SwiftUI
import SwiftData

struct VehicleHistoryView: View {
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query private var documentRecords: [DocumentRecord]
    @Query private var faultRecords: [FaultRecord]
    @Query private var warrantyPlans: [WarrantyPlan]

    @State private var filter: MaintenanceHistoryFilter = .all
    @State private var searchText = ""
    @State private var showExportShare = false
    @State private var exportPDFData: Data?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var scopedMaintenance: [MaintenanceRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.maintenanceRecords(for: profile.id, from: maintenanceRecords)
    }

    private var scopedDocuments: [DocumentRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.documentRecords(for: profile.id, from: documentRecords)
    }

    private var scopedFaults: [FaultRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.faultRecords(for: profile.id, from: faultRecords)
    }

    private var scopedWarrantyPlans: [WarrantyPlan] {
        guard let profile = activeProfile else { return [] }
        return warrantyPlans.filter { $0.vehicleID == profile.id }
    }

    private var visibleFilters: [MaintenanceHistoryFilter] {
        if WarrantySupport.showsWarrantyFeatures(for: activeProfile) {
            return MaintenanceHistoryFilter.allCases
        }
        return MaintenanceHistoryFilter.allCases.filter { $0 != .warranty }
    }

    private var entries: [MaintenanceHistoryEntry] {
        MaintenanceSupport.filteredHistoryEntries(
            maintenanceRecords: scopedMaintenance,
            documents: scopedDocuments,
            faults: scopedFaults,
            warrantyPlans: WarrantySupport.showsWarrantyFeatures(for: activeProfile) ? scopedWarrantyPlans : [],
            filter: filter,
            searchText: searchText,
            ascending: true
        )
    }

    private var exportEntries: [MaintenanceHistoryEntry] {
        MaintenanceSupport.historyEntries(
            maintenanceRecords: scopedMaintenance,
            documents: scopedDocuments,
            faults: scopedFaults,
            warrantyPlans: WarrantySupport.showsWarrantyFeatures(for: activeProfile) ? scopedWarrantyPlans : [],
            ascending: true
        )
    }

    var body: some View {
        Group {
            if activeProfile != nil {
                historyContent
            } else {
                ContentUnavailableView(
                    "No vehicle selected",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Choose a vehicle to view its history.")
                )
            }
        }
        .appScreenBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search history")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportHistory()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(activeProfile == nil || exportEntries.isEmpty)
                .accessibilityLabel("Share vehicle history")
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let exportPDFData {
                VehicleHistoryShareSheet(pdfData: exportPDFData)
            }
        }
        .onChange(of: activeProfile?.warrantyAvailable) { _, _ in
            if !visibleFilters.contains(filter) {
                filter = .all
            }
        }
    }

    private var historyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                AppHeroSection(
                    systemImage: "clock.arrow.circlepath",
                    title: "Vehicle history",
                    subtitle: "A chronological record of maintenance, warranty, documents and faults — ready to share when selling or claiming."
                )

                Picker("Filter", selection: $filter) {
                    ForEach(visibleFilters) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if entries.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppScreenMetrics.cardInteriorPadding)
                        .background(LyneqoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
                } else {
                    VehicleHistoryTimelineView(entries: entries)
                        .padding(AppScreenMetrics.cardInteriorPadding)
                        .background(LyneqoTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
        }
    }

    private var emptyMessage: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filter == .all
                ? "No significant events recorded yet. Add maintenance, documents, faults or warranty activity to build this timeline."
                : "No \(filter.displayName.lowercased()) events match the current filter."
        }
        return "No history matches your search."
    }

    private func exportHistory() {
        guard let profile = activeProfile else { return }
        exportPDFData = VehicleHistoryPDFBuilder.buildPDF(
            input: .init(
                vehicleName: profile.name,
                vehicleKind: profile.kind,
                entries: exportEntries
            )
        )
        showExportShare = true
    }
}

private struct VehicleHistoryTimelineView: View {
    let entries: [MaintenanceHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VehicleHistoryTimelineRow(
                    entry: entry,
                    isLast: index == entries.count - 1
                )
            }
        }
    }
}

private struct VehicleHistoryTimelineRow: View {
    let entry: MaintenanceHistoryEntry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 8)
                    Text(kindLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.15))
                        .foregroundStyle(tint)
                        .clipShape(Capsule())
                }

                Text(Formatters.date(entry.date))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : AppScreenMetrics.sectionSpacing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.title), \(kindLabel), \(Formatters.date(entry.date)), \(entry.subtitle)")
        }
    }

    private var kindLabel: String {
        switch entry.kind {
        case .maintenance: return "Maintenance"
        case .document: return "Document"
        case .faultRaised: return "Fault"
        case .faultResolved: return "Repaired"
        case .warrantyPurchase: return "Warranty"
        case .warranty: return "Warranty"
        }
    }

    private var tint: Color {
        switch entry.kind {
        case .maintenance: return AppColors.blue
        case .document: return AppColors.orange
        case .faultRaised: return AppColors.red
        case .faultResolved: return AppColors.green
        case .warrantyPurchase, .warranty: return AppColors.purple
        }
    }
}

private struct VehicleHistoryShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pdfData: Data

    private var shareURL: URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Vehicle-History-\(UUID().uuidString).pdf")
        do {
            try pdfData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppScreenMetrics.sectionSpacing) {
                Text("Your vehicle history is ready to share, save or print.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share history", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius))
                    }
                    .padding(.horizontal)
                } else {
                    Text("Could not prepare the history PDF for sharing.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }

                Spacer()
            }
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
