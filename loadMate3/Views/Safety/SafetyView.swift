import SwiftUI
import SwiftData

enum SafetySegment: String, CaseIterable, Identifiable {
    case today = "Today"
    case checklists = "Checklists"
    case history = "History"

    var id: String { rawValue }
}

struct SafetyView: View {
    var onNavigateToMaintenance: (() -> Void)?

    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var allLoadedItems: [LoadedItem]
    @Query(sort: \ChecklistSection.sortOrder) private var checklistSections: [ChecklistSection]
    @Query private var tyreRecords: [TyreRecord]
    @StateObject private var summaryVM = SummaryViewModel()

    @State private var segment: SafetySegment = .today
    @State private var showAddTrip = false
    @State private var newTripName = ""
    @State private var tripPendingRename: Trip?
    @State private var tripRenameField = ""
    @State private var showChecklist = false
    @State private var showDepartureChecklist = false
    @State private var showArrivalChecklist = false
    @State private var showStorageChecklist = false

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var activeTrip: Trip? {
        TripStore.activeTrip(for: activeProfile)
    }

    private var profileTrips: [Trip] {
        TripStore.sortedTrips(for: activeProfile)
    }

    private var profileLoadedItems: [LoadedItem] {
        TripStore.loadedItems(for: activeTrip, from: allLoadedItems)
    }

    private var activeTyreRecords: [TyreRecord] {
        TyreStore.activeRecords(for: activeProfile, from: tyreRecords)
    }

    private var todayChecklist: [SafetyCheckItem] {
        SafetySupport.todayChecklist(
            profile: activeProfile,
            caravanSummary: summaryVM.caravanSummary,
            motorhomeSummary: summaryVM.motorhomeSummary,
            checklistSections: checklistSections,
            tyreRecords: activeTyreRecords
        )
    }

    var body: some View {
        if usePadLayout {
            SafetyPadView(onNavigateToMaintenance: onNavigateToMaintenance)
        } else {
            phoneBody
        }
    }

    private var phoneBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    Picker("Safety section", selection: $segment) {
                        ForEach(SafetySegment.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let profile = activeProfile, !profileTrips.isEmpty {
                        HomeTripSelectorBar(
                            profile: profile,
                            trips: profileTrips,
                            activeTrip: activeTrip,
                            showAddTrip: $showAddTrip,
                            tripPendingRename: $tripPendingRename,
                            tripRenameField: $tripRenameField
                        )
                    }

                    switch segment {
                    case .today:
                        todayContent
                    case .checklists:
                        checklistsContent
                    case .history:
                        historyContent
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Safety")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChecklist = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add safety check")
                }
            }
            .task(id: profileLoadedItems.map(\.id)) {
                summaryVM.refresh(profile: activeProfile, trip: activeTrip, loadedItems: profileLoadedItems)
            }
            .sheet(isPresented: $showChecklist) {
                NavigationStack { ChecklistView() }
            }
            .sheet(isPresented: $showDepartureChecklist) {
                NavigationStack { ChecklistView() }
            }
            .sheet(isPresented: $showArrivalChecklist) {
                NavigationStack { ChecklistView() }
            }
            .sheet(isPresented: $showStorageChecklist) {
                NavigationStack { ChecklistView() }
            }
            .sheet(isPresented: $showAddTrip, onDismiss: { newTripName = "" }) {
                AddTripSheet(name: $newTripName) {
                    guard let profile = activeProfile else { return }
                    let trimmed = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    _ = TripStore.addTrip(name: trimmed, to: profile, in: modelContext)
                    newTripName = ""
                    showAddTrip = false
                }
            }
            .alert("Rename trip", isPresented: Binding(
                get: { tripPendingRename != nil },
                set: { if !$0 { tripPendingRename = nil } }
            )) {
                TextField("Trip name", text: $tripRenameField)
                Button("Save") {
                    if let trip = tripPendingRename {
                        TripStore.renameTrip(trip, name: tripRenameField, in: modelContext)
                    }
                    tripPendingRename = nil
                }
                Button("Cancel", role: .cancel) { tripPendingRename = nil }
            }
        }
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            readinessBanner

            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                Text("Today's Safety Status")
                    .font(.headline.weight(.semibold))

                VStack(spacing: 0) {
                    ForEach(todayChecklist) { item in
                        safetyCheckRow(item)
                        if item.id != todayChecklist.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(AppScreenMetrics.cardInteriorPadding)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))

                if tyreChecklistItem?.status == .due {
                    Button {
                        onNavigateToMaintenance?()
                    } label: {
                        HStack {
                            Text("Review tyres")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                Text("Quick Checklists")
                    .font(.headline.weight(.semibold))
                quickChecklistRow(title: "Departure checklist", systemImage: "list.clipboard.fill") {
                    showDepartureChecklist = true
                }
                quickChecklistRow(title: "Arrival / pitching checklist", systemImage: "tent.fill") {
                    showArrivalChecklist = true
                }
                quickChecklistRow(title: "Storage checklist", systemImage: "archivebox.fill") {
                    showStorageChecklist = true
                }
            }

            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                tyreAlertsCard
                recentActivityCard
            }
        }
    }

    private var readinessBanner: some View {
        let ready = SafetySupport.isReadyToTravel(checklist: todayChecklist)
        return HStack(spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: ready ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(ready ? AppColors.green : AppColors.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(ready ? "Ready to Travel" : "Action Needed")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ready ? AppColors.green : AppColors.orange)
                Text(ready ? "All critical checks complete" : "\(SafetySupport.dueCount(in: todayChecklist)) checks still due")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            Spacer()
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background((ready ? AppColors.green : AppColors.orange).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private var tyreChecklistItem: SafetyCheckItem? {
        todayChecklist.first { $0.id == "tyre-pressure" }
    }

    private func safetyCheckAction(for item: SafetyCheckItem) -> (() -> Void)? {
        guard item.status == .due else { return nil }
        switch item.id {
        case "tyre-pressure":
            guard onNavigateToMaintenance != nil else { return nil }
            return { onNavigateToMaintenance?() }
        default:
            return nil
        }
    }

    @ViewBuilder
    private func safetyCheckRow(_ item: SafetyCheckItem) -> some View {
        let action = safetyCheckAction(for: item)
        let content = HStack(spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: item.status == .complete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(item.status == .complete ? AppColors.green : AppColors.orange)
            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
            Spacer()
            Text(item.status == .complete ? "Complete" : "Due")
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.status == .complete ? AppColors.green : AppColors.orange)
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.orange)
            }
        }
        .padding(.vertical, 6)

        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func quickChecklistRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(AppScreenMetrics.cardInteriorPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var tyreAlertsCard: some View {
        Button {
            onNavigateToMaintenance?()
        } label: {
            VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                HStack {
                    Text("Tyre Status")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Text("Review tyres")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Label("Oldest tyre: \(SafetySupport.oldestTyreDescription(records: activeTyreRecords))", systemImage: "circle.circle")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                if let tyreItem = tyreChecklistItem {
                    Label(
                        tyreItem.status == .complete ? "Tyre pressures checked" : "Tyre pressures need checking",
                        systemImage: tyreItem.status == .complete ? "checkmark.circle" : "exclamationmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(tyreItem.status == .complete ? AppColors.green : AppColors.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppScreenMetrics.cardInteriorPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            Text("Recent Activity")
                .font(.subheadline.weight(.semibold))
            ForEach(SafetySupport.recentActivity(from: todayChecklist)) { item in
                Label {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.title).font(.caption)
                        Text(item.subtitle).font(.caption2).foregroundStyle(AppColors.textSupporting)
                    }
                } icon: {
                    Image(systemName: item.isWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(item.isWarning ? AppColors.orange : AppColors.green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private var checklistsContent: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Saved checklists for this vehicle.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
            quickChecklistRow(title: "Departure checklist", systemImage: "list.clipboard.fill") {
                showDepartureChecklist = true
            }
            quickChecklistRow(title: "Arrival / pitching checklist", systemImage: "tent.fill") {
                showArrivalChecklist = true
            }
            quickChecklistRow(title: "Storage checklist", systemImage: "archivebox.fill") {
                showStorageChecklist = true
            }
            AppPrimaryButton("Open full checklist", systemImage: "checklist") {
                showChecklist = true
            }
        }
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            ForEach(SafetySupport.recentActivity(from: todayChecklist)) { item in
                HStack {
                    Image(systemName: item.isWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(item.isWarning ? AppColors.orange : AppColors.green)
                    VStack(alignment: .leading) {
                        Text(item.title).font(.subheadline.weight(.medium))
                        Text(item.subtitle).font(.caption).foregroundStyle(AppColors.textSupporting)
                    }
                    Spacer()
                }
                .padding(AppScreenMetrics.cardInteriorPadding)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
            }
        }
    }
}
