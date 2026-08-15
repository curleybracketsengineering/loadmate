import PDFKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct MaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.usePadLayout) private var usePadLayout
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query private var documentRecords: [DocumentRecord]
    @Query private var faultRecords: [FaultRecord]
    @Query private var warrantyPlans: [WarrantyPlan]

    @State private var showCreateDialog = false
    @State private var showMaintenanceCreate = false
    @State private var showDocumentCreate = false
    @State private var showFaultCreate = false
    @State private var showMaintenanceList = false
    @State private var showDocumentsList = false
    @State private var showFaultsList = false
    @State private var showHistory = false

    @State private var selectedMaintenanceRecord: MaintenanceRecord?
    @State private var selectedDocumentRecord: DocumentRecord?
    @State private var selectedFaultRecord: FaultRecord?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(
            profiles: profiles,
            appState: AppStateStore.canonical(from: appStates)
        )
    }

    private var scopedMaintenanceRecords: [MaintenanceRecord] {
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

    private var summary: MaintenanceDashboardSummary {
        MaintenanceSupport.dashboardSummary(
            maintenanceRecords: scopedMaintenanceRecords,
            documents: scopedDocuments,
            faults: scopedFaults
        )
    }

    private var reminderItems: [MaintenanceReminderItem] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.reminderItems(
            maintenanceRecords: scopedMaintenanceRecords,
            documents: scopedDocuments,
            warrantyPlans: warrantyPlans,
            vehicleID: profile.id,
            warrantyAvailable: profile.warrantyAvailable,
            profile: profile
        )
        .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = activeProfile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                            VehicleLookupSummarySection(profile: profile)
                            summarySection
                            remindersSection
                            faultDashboardSection
                            maintenancePreviewSection(profile: profile)
                            documentsPreviewSection
                        }
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.top, AppScreenMetrics.verticalScreenPadding)
                        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                        .padReadableContent(maxWidth: usePadLayout ? 960 : PadContentLayout.readableMaxWidth)
                    }
                } else {
                    ContentUnavailableView(
                        "No vehicle selected",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Add or select a caravan or motorhome in Settings to manage maintenance records.")
                    )
                }
            }
            .appScreenBackground()
            .appPrincipalTabTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateDialog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add maintenance item")
                }
            }
        }
        .confirmationDialog("Add", isPresented: $showCreateDialog, titleVisibility: .visible) {
            Button("Maintenance record") { showMaintenanceCreate = true }
            Button("Fault") { showFaultCreate = true }
            Button("Document") { showDocumentCreate = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showMaintenanceCreate) {
            if let profile = activeProfile {
                MaintenanceRecordEditorView(profile: profile)
            }
        }
        .sheet(isPresented: $showDocumentCreate) {
            if let profile = activeProfile {
                DocumentRecordEditorView(profile: profile)
            }
        }
        .sheet(isPresented: $showFaultCreate) {
            if let profile = activeProfile {
                FaultRecordEditorView(
                    profile: profile,
                    maintenanceRecords: scopedMaintenanceRecords,
                    defaultWarrantyRelated: WarrantySupport.plan(for: profile.id, from: warrantyPlans) != nil
                )
            }
        }
        .sheet(item: $selectedMaintenanceRecord) { record in
            if let profile = activeProfile {
                MaintenanceRecordEditorView(profile: profile, record: record)
            }
        }
        .sheet(item: $selectedDocumentRecord) { record in
            if let profile = activeProfile {
                DocumentRecordEditorView(profile: profile, record: record)
            }
        }
        .sheet(item: $selectedFaultRecord) { record in
            if let profile = activeProfile {
                FaultRecordEditorView(
                    profile: profile,
                    record: record,
                    maintenanceRecords: scopedMaintenanceRecords
                )
            }
        }
        .sheet(isPresented: $showMaintenanceList) {
            MaintenanceRecordsListView(records: scopedMaintenanceRecords) { record in
                selectedMaintenanceRecord = record
            }
        }
        .sheet(isPresented: $showDocumentsList) {
            DocumentsListView(records: scopedDocuments) { record in
                selectedDocumentRecord = record
            }
        }
        .sheet(isPresented: $showFaultsList) {
            FaultsListView(records: scopedFaults) { record in
                selectedFaultRecord = record
            }
        }
        .sheet(isPresented: $showHistory) {
            MaintenanceHistoryTimelineView(
                maintenanceRecords: scopedMaintenanceRecords,
                documentRecords: scopedDocuments,
                faultRecords: scopedFaults,
                warrantyPlans: WarrantySupport.showsWarrantyFeatures(for: activeProfile)
                    ? warrantyPlans.filter { $0.vehicleID == activeProfile?.id }
                    : []
            )
        }
    }

    private var summarySection: some View {
        AppSettingsSection("Summary", caption: "Upcoming work, open issues and recent activity at a glance.") {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: AppScreenMetrics.controlSpacing),
                    count: 3
                ),
                spacing: AppScreenMetrics.controlSpacing
            ) {
                MaintenanceDashboardCard(
                    title: "Upcoming",
                    value: summary.upcomingTitle,
                    detail: summary.upcomingSubtitle,
                    tint: reminderItems.first.map { tintColor(for: $0.dueDate) } ?? .accentColor,
                    action: { showHistory = true }
                )
                MaintenanceDashboardCard(
                    title: "Outstanding",
                    value: outstandingSummaryValue,
                    detail: outstandingSummaryDetail,
                    tint: outstandingSummaryTint,
                    action: {
                        if summary.outstandingFaults > 0 {
                            showFaultsList = true
                        } else {
                            showDocumentsList = true
                        }
                    }
                )
                MaintenanceDashboardCard(
                    title: "Recent Activity",
                    value: summary.recentActivityTitle,
                    detail: summary.recentActivitySubtitle,
                    tint: .secondary,
                    action: { showHistory = true }
                )
            }
        }
    }

    private var remindersSection: some View {
        AppSettingsSection("Reminders", caption: "Due and overdue items that should stay visible on the dashboard.") {
            if reminderItems.isEmpty {
                Text("No reminders yet. Add reminder dates or expiry dates to highlight future maintenance.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(Array(reminderItems.prefix(5))) { item in
                        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(tintColor(for: item.dueDate))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                Text(MaintenanceSupport.relativeDueText(for: item.dueDate))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(tintColor(for: item.dueDate))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var faultDashboardSection: some View {
        MaintenanceCompactSectionRow(
            caption: "Track issues that still need attention and prioritise the important ones first.",
            label: "Faults",
            addAccessibilityLabel: "Add fault",
            viewAccessibilityLabel: "View all faults",
            onAdd: { showFaultCreate = true },
            onView: { showFaultsList = true }
        ) {
            HStack(spacing: 10) {
                MaintenanceMetricCount(
                    count: MaintenanceSupport.highPriorityFaultCount(scopedFaults),
                    tint: .red,
                    accessibilityLabel: "High priority faults"
                )
                MaintenanceMetricCount(
                    count: MaintenanceSupport.mediumPriorityFaultCount(scopedFaults),
                    tint: .orange,
                    accessibilityLabel: "Medium priority faults"
                )
                MaintenanceMetricCount(
                    count: MaintenanceSupport.lowPriorityFaultCount(scopedFaults),
                    tint: .yellow,
                    accessibilityLabel: "Low priority faults"
                )
            }
        }
    }

    private func maintenancePreviewSection(profile: VehicleProfile) -> some View {
        MaintenanceCompactSectionRow(
            caption: "Scheduled services, repairs and ongoing upkeep for this \(profile.kind.displayName.lowercased()).",
            label: "Maintenance",
            addAccessibilityLabel: "Add maintenance record",
            viewAccessibilityLabel: "View all maintenance",
            onAdd: { showMaintenanceCreate = true },
            onView: { showMaintenanceList = true }
        ) {
            MaintenanceMetricCount(
                count: scopedMaintenanceRecords.count,
                tint: .blue,
                accessibilityLabel: "Maintenance records"
            )
        }
    }

    private var documentsPreviewSection: some View {
        MaintenanceCompactSectionRow(
            caption: "Keep service paperwork, policies and certificates together with the vehicle record.",
            label: "Documents",
            addAccessibilityLabel: "Add document",
            viewAccessibilityLabel: "View all documents",
            onAdd: { showDocumentCreate = true },
            onView: { showDocumentsList = true }
        ) {
            MaintenanceMetricCount(
                count: scopedDocuments.count,
                tint: .blue,
                accessibilityLabel: "Stored documents"
            )
        }
    }

    private func dayDelta(for date: Date) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
    }

    private var outstandingSummaryValue: String {
        if summary.outstandingFaults == 0 && summary.documentCount == 0 {
            return "All clear"
        }
        var parts: [String] = []
        if summary.outstandingFaults > 0 {
            parts.append("\(summary.outstandingFaults) fault\(summary.outstandingFaults == 1 ? "" : "s")")
        }
        if summary.documentCount > 0 {
            parts.append("\(summary.documentCount) doc\(summary.documentCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " • ")
    }

    private var outstandingSummaryDetail: String {
        if summary.outstandingFaults > 0 {
            return "\(faultDetailText) • \(summary.documentCount) stored"
        }
        if summary.documentCount > 0 {
            return "No open faults • paperwork on file"
        }
        return "Faults and documents will appear here"
    }

    private var outstandingSummaryTint: Color {
        if summary.outstandingFaults > 0 { return .orange }
        if summary.documentCount > 0 { return .blue }
        return AppColors.green
    }

    private var faultDetailText: String {
        "\(MaintenanceSupport.highPriorityFaultCount(scopedFaults)) high, \(MaintenanceSupport.mediumPriorityFaultCount(scopedFaults)) medium, \(MaintenanceSupport.lowPriorityFaultCount(scopedFaults)) low"
    }

    private func tintColor(for dueDate: Date) -> Color {
        let delta = dayDelta(for: dueDate)

        if delta < 0 { return .red }
        if delta <= 7 { return .orange }
        return .accentColor
    }
}

private struct MaintenanceCompactSectionRow<Metrics: View>: View {
    let caption: String
    let label: String
    let addAccessibilityLabel: String
    let viewAccessibilityLabel: String
    let onAdd: () -> Void
    let onView: () -> Void
    @ViewBuilder let metrics: Metrics

    init(
        caption: String,
        label: String,
        addAccessibilityLabel: String,
        viewAccessibilityLabel: String,
        onAdd: @escaping () -> Void,
        onView: @escaping () -> Void,
        @ViewBuilder metrics: () -> Metrics
    ) {
        self.caption = caption
        self.label = label
        self.addAccessibilityLabel = addAccessibilityLabel
        self.viewAccessibilityLabel = viewAccessibilityLabel
        self.onAdd = onAdd
        self.onView = onView
        self.metrics = metrics()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)
            AppGroupedCard {
                HStack(spacing: AppScreenMetrics.controlSpacing) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))

                    metrics

                    Spacer(minLength: 0)

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(addAccessibilityLabel)

                    Button(action: onView) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewAccessibilityLabel)
                }
            }
        }
    }
}

private struct MaintenanceMetricCount: View {
    let count: Int
    let tint: Color
    let accessibilityLabel: String

    var body: some View {
        Text("\(count)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .frame(minWidth: 18)
            .accessibilityLabel("\(accessibilityLabel): \(count)")
    }
}

private struct MaintenanceDashboardCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .fill(LyneqoTheme.softTeal)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MaintenanceRecordsListView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [MaintenanceRecord]
    let onSelect: (MaintenanceRecord) -> Void

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    Text("No maintenance records yet.")
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ForEach(records) { record in
                        Button {
                            dismiss()
                            onSelect(record)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title.isEmpty ? record.category.displayName : record.title)
                                    .foregroundStyle(Color.primary)
                                Text("\(record.category.displayName) • \(Formatters.date(record.serviceDate))")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct DocumentsListView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [DocumentRecord]
    let onSelect: (DocumentRecord) -> Void

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    Text("No documents stored yet.")
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ForEach(records) { record in
                        Button {
                            dismiss()
                            onSelect(record)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title.isEmpty ? record.category.displayName : record.title)
                                    .foregroundStyle(Color.primary)
                                Text("\(record.category.displayName) • \(Formatters.date(record.dateAdded))")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct FaultsListView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [FaultRecord]
    let onSelect: (FaultRecord) -> Void

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    Text("No faults recorded yet.")
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ForEach(records) { record in
                        Button {
                            dismiss()
                            onSelect(record)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title.isEmpty ? "Untitled fault" : record.title)
                                    .foregroundStyle(Color.primary)
                                Text("\(record.severity.displayName) • \(record.status.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Faults")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct MaintenanceHistoryTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    let maintenanceRecords: [MaintenanceRecord]
    let documentRecords: [DocumentRecord]
    let faultRecords: [FaultRecord]
    var warrantyPlans: [WarrantyPlan] = []

    @State private var filter: MaintenanceHistoryFilter = .all
    @State private var searchText = ""

    private var visibleFilters: [MaintenanceHistoryFilter] {
        if warrantyPlans.isEmpty {
            return MaintenanceHistoryFilter.allCases.filter { $0 != .warranty }
        }
        return MaintenanceHistoryFilter.allCases
    }

    private var entries: [MaintenanceHistoryEntry] {
        MaintenanceSupport.filteredHistoryEntries(
            maintenanceRecords: maintenanceRecords,
            documents: documentRecords,
            faults: faultRecords,
            warrantyPlans: warrantyPlans,
            filter: filter,
            searchText: searchText
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(visibleFilters) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if entries.isEmpty {
                    Section {
                        Text("No history matches the current filter.")
                            .foregroundStyle(AppColors.textSupporting)
                    }
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                            Text(entry.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                            Text(Formatters.date(entry.date))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search titles, notes and suppliers")
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct MaintenanceRecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let record: MaintenanceRecord?

    @State private var title: String
    @State private var category: MaintenanceCategory
    @State private var serviceDate: Date
    @State private var costText: String
    @State private var supplier: String
    @State private var notes: String
    @State private var hasReminderDate: Bool
    @State private var reminderDate: Date
    @State private var mileageText: String
    @State private var pendingAttachments: [MaintenanceAttachmentDraft] = []

    init(profile: VehicleProfile, record: MaintenanceRecord? = nil) {
        self.profile = profile
        self.record = record
        _title = State(initialValue: record?.title ?? "")
        _category = State(initialValue: record?.category ?? MaintenanceSupport.maintenanceCategories(for: profile.kind).first ?? .generalMaintenance)
        _serviceDate = State(initialValue: record?.serviceDate ?? Date())
        _costText = State(initialValue: record?.cost.map { Formatters.currencyInputString($0) } ?? "")
        _supplier = State(initialValue: record?.supplier ?? "")
        _notes = State(initialValue: record?.notes ?? "")
        _hasReminderDate = State(initialValue: record?.reminderDate != nil)
        _reminderDate = State(initialValue: record?.reminderDate ?? Date())
        _mileageText = State(initialValue: record?.vehicleMileage.map { Self.integerInputString($0) } ?? "")
    }

    private var availableCategories: [MaintenanceCategory] {
        MaintenanceSupport.maintenanceCategories(for: profile.kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "wrench.and.screwdriver",
                        title: record == nil ? "New maintenance record" : "Maintenance record",
                        subtitle: "Capture the work carried out with as little typing as possible."
                    )

                    AppSettingsSection("Details") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Title", placeholder: "e.g. Annual Habitation Service", text: $title)
                            Picker("Category", selection: $category) {
                                ForEach(availableCategories) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            DatePicker("Date", selection: $serviceDate, displayedComponents: .date)
                            AppLabeledTextField("Cost", placeholder: "Optional", text: $costText, keyboard: .decimalPad)
                            AppLabeledTextField("Supplier / Garage", placeholder: "Optional", text: $supplier)
                            if profile.kind == .motorhome {
                                AppLabeledTextField("Vehicle Mileage", placeholder: "Optional", text: $mileageText, keyboard: .numberPad)
                            }
                        }
                    }

                    AppSettingsSection("Reminder") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            Toggle("Add reminder date", isOn: $hasReminderDate)
                            if hasReminderDate {
                                DatePicker("Reminder Date", selection: $reminderDate, displayedComponents: .date)
                            }
                        }
                    }

                    AppSettingsSection("Notes") {
                        MaintenanceNotesEditor(text: $notes)
                    }

                    MaintenanceAttachmentEditorSection(
                        pendingAttachments: $pendingAttachments,
                        existingAttachments: record?.attachmentsList ?? [],
                        onDeleteExisting: { attachment in
                            MaintenanceAttachmentStore.delete(attachment, in: modelContext)
                        }
                    )

                    AppPrimaryButton(record == nil ? "Save maintenance record" : "Save changes", systemImage: "checkmark.circle.fill") {
                        save()
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle(record == nil ? "Add Maintenance" : "Edit Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let target = record ?? MaintenanceStore.createRecord(for: profile.id, in: modelContext)
        MaintenanceStore.save(
            record: target,
            title: title.isEmpty ? category.displayName : title,
            category: category,
            serviceDate: serviceDate,
            cost: Formatters.parseCurrency(costText),
            supplier: supplier,
            notes: notes,
            reminderDate: hasReminderDate ? reminderDate : nil,
            vehicleMileage: profile.kind == .motorhome ? Self.parseInteger(mileageText) : nil,
            in: modelContext
        )
        if !pendingAttachments.isEmpty {
            MaintenanceAttachmentStore.save(
                drafts: pendingAttachments,
                to: .maintenance(target),
                in: modelContext
            )
        }
        dismiss()
    }

    private static func parseInteger(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func integerInputString(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

struct DocumentRecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let record: DocumentRecord?

    @State private var title: String
    @State private var category: DocumentCategory
    @State private var dateAdded: Date
    @State private var hasExpiryDate: Bool
    @State private var expiryDate: Date
    @State private var hasReminderDate: Bool
    @State private var reminderDate: Date
    @State private var notes: String
    @State private var pendingAttachments: [MaintenanceAttachmentDraft] = []

    init(profile: VehicleProfile, record: DocumentRecord? = nil) {
        self.profile = profile
        self.record = record
        _title = State(initialValue: record?.title ?? "")
        _category = State(initialValue: record?.category ?? .other)
        _dateAdded = State(initialValue: record?.dateAdded ?? Date())
        _hasExpiryDate = State(initialValue: record?.expiryDate != nil)
        _expiryDate = State(initialValue: record?.expiryDate ?? Date())
        _hasReminderDate = State(initialValue: record?.reminderDate != nil)
        _reminderDate = State(initialValue: record?.reminderDate ?? Date())
        _notes = State(initialValue: record?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "doc.text.image",
                        title: record == nil ? "New document" : "Document",
                        subtitle: "Store certificates, invoices, manuals and scanned paperwork locally on this device."
                    )

                    AppSettingsSection("Details") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Title", placeholder: "e.g. Insurance Renewal", text: $title)
                            Picker("Category", selection: $category) {
                                ForEach(DocumentCategory.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            DatePicker("Date Added", selection: $dateAdded, displayedComponents: .date)
                            Toggle("Add expiry date", isOn: $hasExpiryDate)
                            if hasExpiryDate {
                                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                            }
                            Toggle("Add reminder date", isOn: $hasReminderDate)
                            if hasReminderDate {
                                DatePicker("Reminder Date", selection: $reminderDate, displayedComponents: .date)
                            }
                        }
                    }

                    AppSettingsSection("Notes") {
                        MaintenanceNotesEditor(text: $notes)
                    }

                    MaintenanceAttachmentEditorSection(
                        pendingAttachments: $pendingAttachments,
                        existingAttachments: record?.attachmentsList ?? [],
                        onDeleteExisting: { attachment in
                            MaintenanceAttachmentStore.delete(attachment, in: modelContext)
                        }
                    )

                    AppPrimaryButton(record == nil ? "Save document" : "Save changes", systemImage: "checkmark.circle.fill") {
                        save()
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle(record == nil ? "Add Document" : "Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let target = record ?? DocumentStore.createRecord(for: profile.id, in: modelContext)
        DocumentStore.save(
            record: target,
            title: title.isEmpty ? category.displayName : title,
            category: category,
            dateAdded: dateAdded,
            expiryDate: hasExpiryDate ? expiryDate : nil,
            reminderDate: hasReminderDate ? reminderDate : nil,
            notes: notes,
            in: modelContext
        )
        if !pendingAttachments.isEmpty {
            MaintenanceAttachmentStore.save(
                drafts: pendingAttachments,
                to: .document(target),
                in: modelContext
            )
        }
        dismiss()
    }
}

struct FaultRecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let record: FaultRecord?
    let maintenanceRecords: [MaintenanceRecord]

    @State private var title: String
    @State private var details: String
    @State private var severity: FaultSeverity
    @State private var status: FaultStatus
    @State private var discoveredDate: Date
    @State private var hasResolvedDate: Bool
    @State private var resolvedDate: Date
    @State private var repairCost: String
    @State private var linkedMaintenanceID: UUID?
    @State private var isWarrantyRelated: Bool
    @State private var pendingAttachments: [MaintenanceAttachmentDraft] = []

    init(
        profile: VehicleProfile,
        record: FaultRecord? = nil,
        maintenanceRecords: [MaintenanceRecord],
        defaultWarrantyRelated: Bool = false,
        suggestAsWarrantyItem: Bool = false
    ) {
        self.profile = profile
        self.record = record
        self.maintenanceRecords = maintenanceRecords
        _title = State(initialValue: record?.title ?? "")
        _details = State(initialValue: record?.details ?? "")
        _severity = State(initialValue: record?.severity ?? .low)
        _status = State(initialValue: record?.status ?? .open)
        _discoveredDate = State(initialValue: record?.discoveredDate ?? Date())
        _hasResolvedDate = State(initialValue: record?.resolvedDate != nil)
        _resolvedDate = State(initialValue: record?.resolvedDate ?? Date())
        _repairCost = State(initialValue: record?.repairCost.map { Formatters.currencyInputString($0) } ?? "")
        _linkedMaintenanceID = State(initialValue: record?.linkedMaintenanceRecord?.id)
        let existingFlag = record?.isWarrantyRelated ?? false
        _isWarrantyRelated = State(
            initialValue: existingFlag || suggestAsWarrantyItem || (record == nil && defaultWarrantyRelated)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "exclamationmark.triangle",
                        title: record == nil ? "New fault" : "Fault details",
                        subtitle: "Track issues until they are repaired, invoiced and closed."
                    )

                    AppSettingsSection(
                        "Warranty",
                        caption: "Turn this on if the issue is covered by or claimed under warranty. It appears on the Warranty screen — open or completed."
                    ) {
                        Toggle("Warranty item", isOn: $isWarrantyRelated)
                    }

                    AppSettingsSection("Details") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Title", placeholder: "e.g. Fridge ignition fault", text: $title)
                            Picker("Severity", selection: $severity) {
                                ForEach(FaultSeverity.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            Picker("Status", selection: $status) {
                                ForEach(FaultStatus.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            DatePicker("Date discovered", selection: $discoveredDate, displayedComponents: .date)
                            if status.isResolved || hasResolvedDate {
                                Toggle("Add resolved date", isOn: $hasResolvedDate)
                                if hasResolvedDate {
                                    DatePicker("Date resolved", selection: $resolvedDate, displayedComponents: .date)
                                }
                            }
                            AppLabeledTextField("Repair cost", placeholder: "Optional", text: $repairCost, keyboard: .decimalPad)
                            Picker("Linked maintenance record", selection: $linkedMaintenanceID) {
                                Text("None").tag(nil as UUID?)
                                ForEach(maintenanceRecords) { maintenance in
                                    Text(maintenance.title.isEmpty ? maintenance.category.displayName : maintenance.title)
                                        .tag(Optional.some(maintenance.id))
                                }
                            }
                        }
                    }

                    AppSettingsSection("Description") {
                        MaintenanceNotesEditor(text: $details)
                    }

                    MaintenanceAttachmentEditorSection(
                        pendingAttachments: $pendingAttachments,
                        existingAttachments: record?.attachmentsList ?? [],
                        onDeleteExisting: { attachment in
                            MaintenanceAttachmentStore.delete(attachment, in: modelContext)
                        }
                    )

                    AppPrimaryButton(record == nil ? "Save fault" : "Save changes", systemImage: "checkmark.circle.fill") {
                        save()
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle(record == nil ? "Add Fault" : "Edit Fault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let target = record ?? FaultStore.createRecord(for: profile.id, in: modelContext)
        let linkedRecord = maintenanceRecords.first(where: { $0.id == linkedMaintenanceID })
        FaultStore.save(
            fault: target,
            title: title.isEmpty ? "Fault" : title,
            details: details,
            severity: severity,
            status: status,
            discoveredDate: discoveredDate,
            resolvedDate: hasResolvedDate ? resolvedDate : nil,
            repairCost: Formatters.parseCurrency(repairCost),
            linkedMaintenanceRecord: linkedRecord,
            isWarrantyRelated: isWarrantyRelated,
            in: modelContext
        )
        if !pendingAttachments.isEmpty {
            MaintenanceAttachmentStore.save(
                drafts: pendingAttachments,
                to: .fault(target),
                in: modelContext
            )
        }
        dismiss()
    }
}

struct MaintenanceAttachmentEditorSection: View {
    @Binding var pendingAttachments: [MaintenanceAttachmentDraft]
    let existingAttachments: [MaintenanceAttachment]
    let onDeleteExisting: (MaintenanceAttachment) -> Void

    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var previewAttachment: AttachmentPreviewSource?

    var body: some View {
        AppSettingsSection("Attachments", caption: "Photos, scans, PDFs and imported files are saved locally with this record.") {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                if existingAttachments.isEmpty && pendingAttachments.isEmpty {
                    Text("No attachments yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppScreenMetrics.controlSpacing) {
                            ForEach(existingAttachments) { attachment in
                                AttachmentThumbnailView(
                                    title: attachment.displayName,
                                    image: MaintenanceAttachmentStore.loadThumbnail(for: attachment),
                                    symbolName: symbolName(for: attachment.fileType)
                                ) {
                                    previewAttachment = .saved(attachment)
                                } onDelete: {
                                    onDeleteExisting(attachment)
                                }
                            }

                            ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, draft in
                                AttachmentThumbnailView(
                                    title: draft.displayName,
                                    image: draft.thumbnailImage ?? imagePreview(for: draft),
                                    symbolName: symbolName(for: draft.fileType)
                                ) {
                                    previewAttachment = .pending(draft)
                                } onDelete: {
                                    pendingAttachments.remove(at: index)
                                }
                            }
                        }
                    }
                }

                AppSecondaryButton("Add attachment") {
                    showSourceDialog = true
                }
            }
        }
        .confirmationDialog("Add attachment", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            if VNDocumentCameraViewController.isSupported {
                Button("Scan Document") { showScanner = true }
            }
            Button("Choose From Photos") { showLibraryPicker = true }
            Button("Choose From Files") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showLibraryPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var drafts: [MaintenanceAttachmentDraft] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let draft = try? MaintenanceAttachmentStore.draft(
                           image: image,
                           fileType: .photo,
                           displayName: "Photo"
                       ) {
                        drafts.append(draft)
                    }
                }
                await MainActor.run {
                    pendingAttachments.append(contentsOf: drafts)
                    selectedPhotoItems = []
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            MaintenanceImagePicker(sourceType: .camera) { image in
                if let draft = try? MaintenanceAttachmentStore.draft(
                    image: image,
                    fileType: .photo,
                    displayName: "Photo"
                ) {
                    pendingAttachments.append(draft)
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            MaintenanceDocumentScanner { scan in
                let draft = MaintenanceAttachmentStore.draft(
                    pdfData: scan.pdfData,
                    displayName: scan.displayName,
                    pageCount: scan.pageCount,
                    fileType: .scannedDocument
                )
                pendingAttachments.append(draft)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image, .item],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            let drafts = urls.compactMap { try? MaintenanceAttachmentStore.draft(fileAt: $0) }
            pendingAttachments.append(contentsOf: drafts)
        }
        .sheet(item: $previewAttachment) { preview in
            AttachmentPreviewView(preview: preview)
        }
    }

    private func imagePreview(for draft: MaintenanceAttachmentDraft) -> UIImage? {
        if draft.fileType == .pdf {
            return MaintenanceAttachmentStore.pdfThumbnail(for: draft.data, maxDimension: 400)
        }
        return UIImage(data: draft.data)
    }

    private func symbolName(for kind: MaintenanceAttachmentKind) -> String {
        switch kind {
        case .photo:
            return "photo"
        case .scannedDocument:
            return "doc.text.viewfinder"
        case .pdf:
            return "doc.richtext"
        case .file:
            return "doc"
        }
    }
}

struct AttachmentThumbnailView: View {
    let title: String
    let image: UIImage?
    let symbolName: String
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LyneqoTheme.softTeal)
                            Image(systemName: symbolName)
                                .font(.title2)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .frame(width: 92, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

enum AttachmentPreviewSource: Identifiable {
    case saved(MaintenanceAttachment)
    case pending(MaintenanceAttachmentDraft)

    var id: String {
        switch self {
        case .saved(let attachment):
            return "saved-\(attachment.id.uuidString)"
        case .pending(let draft):
            return "pending-\(draft.displayName)-\(draft.data.count)"
        }
    }
}

struct AttachmentPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: AttachmentPreviewSource

    var body: some View {
        NavigationStack {
            Group {
                switch preview {
                case .saved(let attachment):
                    previewBody(
                        title: attachment.displayName,
                        fileType: attachment.fileType,
                        data: MaintenanceAttachmentStore.loadData(for: attachment)
                    )
                case .pending(let draft):
                    previewBody(
                        title: draft.displayName,
                        fileType: draft.fileType,
                        data: draft.data
                    )
                }
            }
            .navigationTitle("Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func previewBody(title: String, fileType: MaintenanceAttachmentKind, data: Data?) -> some View {
        if let data {
            switch fileType {
            case .pdf, .scannedDocument:
                PDFDocumentView(data: data)
            case .photo, .file:
                if let image = UIImage(data: data) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                            Text(title)
                                .font(.headline)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Preview unavailable", systemImage: "doc")
                }
            }
        } else {
            ContentUnavailableView("Preview unavailable", systemImage: "doc")
        }
    }
}

struct PDFDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

private struct MaintenanceNotesEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 120)
            .padding(8)
            .background(LyneqoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                    .strokeBorder(LyneqoTheme.border, lineWidth: 1)
            }
    }
}

struct MaintenanceImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            DispatchQueue.main.async {
                context.coordinator.parent.dismiss()
            }
            picker.delegate = context.coordinator
            return picker
        }
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MaintenanceImagePicker

        init(parent: MaintenanceImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ScannedDocumentResult {
    let pdfData: Data
    let pageCount: Int
    let displayName: String
}

struct MaintenanceDocumentScanner: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onScanComplete: (ScannedDocumentResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: MaintenanceDocumentScanner

        init(parent: MaintenanceDocumentScanner) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: any Error
        ) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pageCount = scan.pageCount
            let images = (0..<pageCount).map { scan.imageOfPage(at: $0) }
            let pdfData = renderPDF(from: images)
            parent.onScanComplete(
                ScannedDocumentResult(
                    pdfData: pdfData,
                    pageCount: pageCount,
                    displayName: "Scanned Document"
                )
            )
            parent.dismiss()
        }

        private func renderPDF(from images: [UIImage]) -> Data {
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
            return renderer.pdfData { context in
                for image in images {
                    context.beginPage()
                    let pageBounds = context.pdfContextBounds
                    let imageSize = image.size
                    let scale = min(pageBounds.width / imageSize.width, pageBounds.height / imageSize.height)
                    let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    let origin = CGPoint(
                        x: (pageBounds.width - drawSize.width) / 2,
                        y: (pageBounds.height - drawSize.height) / 2
                    )
                    image.draw(in: CGRect(origin: origin, size: drawSize))
                }
            }
        }
    }
}
