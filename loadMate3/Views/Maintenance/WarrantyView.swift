import PDFKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct WarrantyView: View {
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var warrantyPlans: [WarrantyPlan]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query private var documentRecords: [DocumentRecord]
    @Query private var faultRecords: [FaultRecord]

    @State private var showSetup = false
    @State private var showEditPlan = false
    @State private var showAddEvent = false
    @State private var showInfo = false
    @State private var showAddDocument = false
    @State private var showExportShare = false
    @State private var exportPDFData: Data?
    @State private var selectedEvent: WarrantyEvent?
    @State private var selectedDocument: DocumentRecord?
    @State private var selectedFault: FaultRecord?
    @State private var showRegenerateConfirm = false

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(
            profiles: profiles,
            appState: AppStateStore.canonical(from: appStates)
        )
    }

    private var activePlan: WarrantyPlan? {
        guard let profile = activeProfile else { return nil }
        return WarrantySupport.plan(for: profile.id, from: warrantyPlans)
    }

    private var scopedDocuments: [DocumentRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.documentRecords(for: profile.id, from: documentRecords)
    }

    private var warrantyDocuments: [DocumentRecord] {
        scopedDocuments.filter {
            $0.category == .warranty || $0.category == .batteryWarranty || $0.category == .dampReport || $0.category == .serviceHistory || $0.category == .purchaseInvoice
        }
    }

    private var warrantyRepairs: [MaintenanceRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.maintenanceRecords(for: profile.id, from: maintenanceRecords)
            .filter { $0.category == .warrantyRepair }
    }

    private var warrantyFaults: [FaultRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.faultRecords(for: profile.id, from: faultRecords)
            .filter { $0.isWarrantyRelated }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = activeProfile {
                    if !profile.warrantyAvailable {
                        warrantyDisabledBody(profile: profile)
                    } else if let plan = activePlan {
                        configuredBody(profile: profile, plan: plan)
                    } else {
                        setupPromptBody(profile: profile)
                    }
                } else {
                    ContentUnavailableView(
                        "No vehicle selected",
                        systemImage: "shield",
                        description: Text("Add or select a caravan or motorhome in Settings to track warranty coverage.")
                    )
                }
            }
            .appScreenBackground()
            .appPrincipalTabTitle("Warranty")
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showSetup) {
            if let profile = activeProfile {
                WarrantyPlanEditorSheet(profile: profile, plan: nil) {
                    if let plan = activePlan {
                        WarrantyStore.generateAnnualEvents(plan: plan, in: modelContext)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditPlan) {
            if let profile = activeProfile, let plan = activePlan {
                WarrantyPlanEditorSheet(profile: profile, plan: plan) {
                    showRegenerateConfirm = true
                }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            if let plan = activePlan {
                WarrantyEventEditorSheet(plan: plan, event: nil, documents: scopedDocuments)
            }
        }
        .sheet(item: $selectedEvent) { event in
            if let plan = activePlan {
                WarrantyEventEditorSheet(plan: plan, event: event, documents: scopedDocuments)
            }
        }
        .sheet(isPresented: $showInfo) {
            WarrantyInfoSheet()
        }
        .sheet(isPresented: $showAddDocument) {
            if let profile = activeProfile {
                WarrantyDocumentEditorView(profile: profile)
            }
        }
        .sheet(item: $selectedDocument) { record in
            if let profile = activeProfile {
                WarrantyDocumentEditorView(profile: profile, record: record)
            }
        }
        .sheet(item: $selectedFault) { record in
            if let profile = activeProfile {
                WarrantyFaultEditorSheet(profile: profile, record: record)
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let exportPDFData {
                WarrantyEvidenceShareSheet(pdfData: exportPDFData)
            }
        }
        .confirmationDialog(
            "Regenerate auto events?",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("Regenerate annual events") {
                if let plan = activePlan {
                    WarrantyStore.generateAnnualEvents(plan: plan, in: modelContext, replaceAutoGenerated: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces auto-generated events with a fresh Year 1–\(activePlan?.durationYears ?? 8) schedule. Manual events are kept.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if activePlan != nil, activeProfile?.warrantyAvailable == true {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add event", systemImage: "plus") { showAddEvent = true }
                    Button("Edit plan", systemImage: "pencil") { showEditPlan = true }
                    Button("Add document", systemImage: "doc.badge.plus") { showAddDocument = true }
                    Button("Export evidence pack", systemImage: "square.and.arrow.up") { exportEvidencePack() }
                    Button("Warranty info", systemImage: "info.circle") { showInfo = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Warranty actions")
            }
        } else if activeProfile?.warrantyAvailable == true {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Set up", systemImage: "plus") { showSetup = true }
            }
        }
    }

    @ViewBuilder
    private func warrantyDisabledBody(profile: VehicleProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                AppHeroSection(
                    systemImage: "shield.slash",
                    title: "Warranty",
                    subtitle: "\(profile.name) \(profile.kind.displayName.lowercased())"
                )

                ContentUnavailableView(
                    "Warranty tracking is off",
                    systemImage: "shield.slash",
                    description: Text("This vehicle is marked as having no warranty to track. Turn on Warranty available in Settings to show the warranty tab again.")
                )
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent(maxWidth: usePadLayout ? 960 : PadContentLayout.readableMaxWidth)
        }
    }

    @ViewBuilder
    private func setupPromptBody(profile: VehicleProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                AppHeroSection(
                    systemImage: "shield.fill",
                    title: "Warranty",
                    subtitle: "\(profile.name) \(profile.kind.displayName.lowercased())"
                )

                WarrantyDisclaimerBanner()

                AppSettingsSection("Get started", caption: "Create a personalised warranty plan with annual service milestones and reminders.") {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                        Text("Record whether your vehicle is under warranty, then build a timeline of required services and inspections.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSupporting)
                        AppPrimaryButton("Set up warranty plan", systemImage: "calendar.badge.plus") {
                            showSetup = true
                        }
                    }
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent(maxWidth: usePadLayout ? 960 : PadContentLayout.readableMaxWidth)
        }
    }

    @ViewBuilder
    private func configuredBody(profile: VehicleProfile, plan: WarrantyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                AppHeroSection(
                    systemImage: "shield.fill",
                    title: "Warranty",
                    subtitle: "\(profile.name) \(profile.kind.displayName.lowercased())"
                )

                WarrantyCoverageBanner(plan: plan)
                WarrantyDisclaimerBanner()

                AppSettingsSection("Service timeline", caption: "Annual warranty services and inspections from purchase date. Tap an event to edit requirements, windows, and evidence.") {
                    WarrantyTimelineView(
                        plan: plan,
                        events: plan.eventsList,
                        onSelectEvent: { selectedEvent = $0 }
                    )
                }

                warrantyFaultsSection
                warrantyRepairsSection
                documentsSection
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent(maxWidth: usePadLayout ? 960 : PadContentLayout.readableMaxWidth)
        }
    }

    private var warrantyFaultsSection: some View {
        AppSettingsSection("Warranty faults", caption: "Issues flagged as warranty-related that may need repair evidence.") {
            if warrantyFaults.isEmpty {
                Text("No warranty faults recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(warrantyFaults) { record in
                        Button { selectedFault = record } label: {
                            warrantyRow(
                                title: record.title.isEmpty ? "Untitled fault" : record.title,
                                subtitle: "\(record.severity.displayName) · \(record.status.displayName)",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var warrantyRepairsSection: some View {
        AppSettingsSection("Warranty repairs", caption: "Repairs carried out under warranty for this vehicle.") {
            if warrantyRepairs.isEmpty {
                Text("No warranty repairs recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(warrantyRepairs) { record in
                        warrantyRow(
                            title: record.title.isEmpty ? record.category.displayName : record.title,
                            subtitle: "\(Formatters.date(record.serviceDate))\(record.supplier.isEmpty ? "" : " · \(record.supplier)")",
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                    }
                }
            }
        }
    }

    private var documentsSection: some View {
        AppSettingsSection("Warranty documents", caption: "Service invoices, damp reports, receipts and warranty paperwork.") {
            if warrantyDocuments.isEmpty {
                Text("No warranty documents yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
            } else {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(warrantyDocuments) { record in
                        Button { selectedDocument = record } label: {
                            warrantyRow(
                                title: record.title.isEmpty ? record.category.displayName : record.title,
                                subtitle: recordSubtitle(for: record),
                                systemImage: "doc.text.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recordSubtitle(for record: DocumentRecord) -> String {
        var parts = [record.category.displayName, Formatters.date(record.dateAdded)]
        if let expiryDate = record.expiryDate {
            parts.append("Expires \(Formatters.date(expiryDate))")
        }
        return parts.joined(separator: " · ")
    }

    private func warrantyRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.purple)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
        }
    }

    private func exportEvidencePack() {
        guard let plan = activePlan, let profile = activeProfile else { return }
        let faults = MaintenanceSupport.faultRecords(for: profile.id, from: faultRecords)
        let maintenance = MaintenanceSupport.maintenanceRecords(for: profile.id, from: maintenanceRecords)
        exportPDFData = WarrantyEvidencePackBuilder.buildPDF(
            input: .init(
                plan: plan,
                events: plan.eventsList,
                documents: scopedDocuments,
                maintenanceRecords: maintenance,
                faults: faults
            )
        )
        showExportShare = true
    }
}

// MARK: - Banner & timeline components

struct WarrantyDisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.secondary)
            Text(WarrantySupport.warrantyDisclaimer)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }
}

private struct WarrantyCoverageBanner: View {
    let plan: WarrantyPlan

    private var coverage: (title: String, detail: String, tintIsPositive: Bool) {
        WarrantySupport.coverageStatusText(plan: plan)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: coverage.tintIsPositive ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(coverage.tintIsPositive ? AppColors.green : AppColors.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(coverage.title)
                    .font(.headline.weight(.bold))
                Text(coverage.detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            Spacer()
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background((coverage.tintIsPositive ? AppColors.green : AppColors.orange).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }
}

private struct WarrantyTimelineView: View {
    let plan: WarrantyPlan
    let events: [WarrantyEvent]
    let onSelectEvent: (WarrantyEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WarrantyTimelineAnchorRow(
                title: "Purchase",
                subtitle: Formatters.date(plan.purchaseDate),
                isLast: events.isEmpty
            )

            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                Button { onSelectEvent(event) } label: {
                    WarrantyTimelineEventRow(
                        event: event,
                        isLast: index == events.count - 1
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct WarrantyTimelineAnchorRow: View {
    let title: String
    let subtitle: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppColors.purple)
                    .frame(width: 12, height: 12)
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }
            .padding(.bottom, isLast ? 0 : AppScreenMetrics.controlSpacing)
        }
    }
}

private struct WarrantyTimelineEventRow: View {
    let event: WarrantyEvent
    let isLast: Bool

    private var status: WarrantyEventStatus {
        WarrantySupport.status(for: event)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.displayTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(WarrantySupport.statusDisplayName(for: status))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }

                Text(Formatters.date(event.scheduledDate))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)

                Text(event.requirementText)
                    .font(.caption)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(WarrantySupport.windowSubtitle(for: event))
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)

                if !event.attachmentsList.isEmpty || !event.linkedDocumentIDs.isEmpty {
                    Text("\(event.attachmentsList.count + event.linkedDocumentIDs.count) evidence item(s)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.purple)
                }
            }
            .padding(.bottom, isLast ? 0 : AppScreenMetrics.sectionSpacing)
        }
    }

    private var statusColor: Color {
        switch status {
        case .completed: return AppColors.green
        case .inWindow: return .accentColor
        case .overdue: return AppColors.red
        case .upcoming: return Color.secondary
        }
    }
}

// MARK: - Plan editor

private struct WarrantyPlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let plan: WarrantyPlan?
    var onSaved: (() -> Void)?

    @State private var isUnderWarranty: Bool
    @State private var hasExpiryDate: Bool
    @State private var warrantyExpiryDate: Date
    @State private var manufacturer: String
    @State private var modelYearText: String
    @State private var purchaseDate: Date
    @State private var purchaseCondition: WarrantyPurchaseCondition
    @State private var ownershipType: WarrantyOwnershipType
    @State private var warrantyType: String
    @State private var durationYears: Int
    @State private var handbookNotes: String
    @State private var selectedTemplateID: String

    init(profile: VehicleProfile, plan: WarrantyPlan?, onSaved: (() -> Void)? = nil) {
        self.profile = profile
        self.plan = plan
        self.onSaved = onSaved
        _isUnderWarranty = State(initialValue: plan?.isUnderWarranty ?? true)
        _hasExpiryDate = State(initialValue: plan?.warrantyExpiryDate != nil)
        _warrantyExpiryDate = State(initialValue: plan?.warrantyExpiryDate ?? Date())
        _manufacturer = State(initialValue: plan?.manufacturer ?? "")
        _modelYearText = State(initialValue: plan?.modelYear.map(String.init) ?? "")
        _purchaseDate = State(initialValue: plan?.purchaseDate ?? Date())
        _purchaseCondition = State(initialValue: plan?.purchaseCondition ?? .newPurchase)
        _ownershipType = State(initialValue: plan?.ownershipType ?? .original)
        _warrantyType = State(initialValue: plan?.warrantyType ?? "")
        _durationYears = State(initialValue: plan?.durationYears ?? WarrantySupport.defaultDurationYears)
        _handbookNotes = State(initialValue: plan?.handbookNotes ?? "")
        _selectedTemplateID = State(initialValue: plan?.templateID ?? "custom")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "shield.fill",
                        title: plan == nil ? "Warranty plan setup" : "Edit warranty plan",
                        subtitle: "Build a personalised plan for this \(profile.kind.displayName.lowercased())."
                    )

                    WarrantyDisclaimerBanner()

                    AppSettingsSection("Coverage") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            Toggle("Vehicle is under warranty", isOn: $isUnderWarranty)
                            Toggle("Set explicit expiry date", isOn: $hasExpiryDate)
                            if hasExpiryDate {
                                DatePicker("Warranty expires", selection: $warrantyExpiryDate, displayedComponents: .date)
                            }
                        }
                    }

                    AppSettingsSection("Template") {
                        Picker("Start from", selection: $selectedTemplateID) {
                            ForEach(WarrantySupport.templateOptions) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                    }

                    AppSettingsSection("Vehicle context") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Manufacturer", placeholder: "e.g. Swift", text: $manufacturer)
                            AppLabeledTextField("Model year", placeholder: "e.g. 2022", text: $modelYearText, keyboard: .numberPad)
                            DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                            Picker("Purchase condition", selection: $purchaseCondition) {
                                ForEach(WarrantyPurchaseCondition.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            Picker("Ownership", selection: $ownershipType) {
                                ForEach(WarrantyOwnershipType.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            AppLabeledTextField("Warranty type", placeholder: "e.g. Structural", text: $warrantyType)
                            Stepper("Duration: \(durationYears) years", value: $durationYears, in: 1...20)
                        }
                    }

                    AppSettingsSection("Handbook notes") {
                        TextEditor(text: $handbookNotes)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
                    }

                    AppPrimaryButton(plan == nil ? "Create plan" : "Save changes", systemImage: "checkmark.circle.fill") {
                        save()
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle(plan == nil ? "Set Up Warranty" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let target = plan ?? WarrantyStore.createPlan(for: profile.id, in: modelContext)
        let modelYear = Int(modelYearText.trimmingCharacters(in: .whitespacesAndNewlines))
        WarrantyStore.save(
            plan: target,
            isUnderWarranty: isUnderWarranty,
            warrantyExpiryDate: hasExpiryDate ? warrantyExpiryDate : nil,
            manufacturer: manufacturer,
            modelYear: modelYear,
            purchaseDate: purchaseDate,
            purchaseCondition: purchaseCondition,
            ownershipType: ownershipType,
            warrantyType: warrantyType,
            durationYears: durationYears,
            handbookNotes: handbookNotes,
            templateID: selectedTemplateID == "custom" ? nil : selectedTemplateID,
            in: modelContext
        )
        onSaved?()
        dismiss()
    }
}

// MARK: - Event editor

private struct WarrantyEventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WarrantyPlan
    let event: WarrantyEvent?
    let documents: [DocumentRecord]

    @State private var yearNumber: Int
    @State private var scheduledDate: Date
    @State private var daysBefore: Int
    @State private var daysAfter: Int
    @State private var serviceType: WarrantyServiceType
    @State private var requirementDescription: String
    @State private var isManual: Bool
    @State private var hasCompletedDate: Bool
    @State private var completedDate: Date
    @State private var linkedDocumentIDs: Set<UUID>
    @State private var pendingAttachments: [MaintenanceAttachmentDraft] = []

    init(plan: WarrantyPlan, event: WarrantyEvent?, documents: [DocumentRecord]) {
        self.plan = plan
        self.event = event
        self.documents = documents
        _yearNumber = State(initialValue: event?.yearNumber ?? 0)
        _scheduledDate = State(initialValue: event?.scheduledDate ?? Date())
        _daysBefore = State(initialValue: event?.daysBefore ?? WarrantySupport.defaultDaysBefore)
        _daysAfter = State(initialValue: event?.daysAfter ?? WarrantySupport.defaultDaysAfter)
        _serviceType = State(initialValue: event?.serviceType ?? .normalService)
        _requirementDescription = State(initialValue: event?.requirementDescription ?? "")
        _isManual = State(initialValue: event?.isManual ?? true)
        _hasCompletedDate = State(initialValue: event?.completedDate != nil)
        _completedDate = State(initialValue: event?.completedDate ?? Date())
        _linkedDocumentIDs = State(initialValue: Set(event?.linkedDocumentIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "calendar.badge.clock",
                        title: event == nil ? "New warranty event" : "Edit warranty event",
                        subtitle: "Set the due date, action window, and requirement description."
                    )

                    AppSettingsSection("Schedule") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            if isManual {
                                AppLabeledTextField("Year label (0 for custom)", placeholder: "0", text: Binding(
                                    get: { yearNumber == 0 ? "" : String(yearNumber) },
                                    set: { yearNumber = Int($0) ?? 0 }
                                ), keyboard: .numberPad)
                            } else {
                                Text("Year \(yearNumber)")
                                    .font(.subheadline.weight(.semibold))
                            }
                            DatePicker("Due date", selection: $scheduledDate, displayedComponents: .date)
                            Stepper("Days before: \(daysBefore)", value: $daysBefore, in: 0...365)
                            Stepper("Days after: \(daysAfter)", value: $daysAfter, in: 0...365)
                        }
                    }

                    AppSettingsSection("Requirement") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            Picker("Service type", selection: $serviceType) {
                                ForEach(WarrantyServiceType.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .onChange(of: serviceType) { _, newValue in
                                if requirementDescription.isEmpty || WarrantyServiceType.allCases.map(\.defaultRequirementDescription).contains(requirementDescription) {
                                    requirementDescription = newValue.defaultRequirementDescription
                                }
                            }

                            TextEditor(text: $requirementDescription)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
                        }
                    }

                    AppSettingsSection("Completion") {
                        Toggle("Mark as completed", isOn: $hasCompletedDate)
                        if hasCompletedDate {
                            DatePicker("Completed date", selection: $completedDate, displayedComponents: .date)
                        }
                    }

                    if !documents.isEmpty {
                        AppSettingsSection("Linked documents", caption: "Attach existing warranty paperwork to this event.") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(documents) { doc in
                                    Toggle(isOn: Binding(
                                        get: { linkedDocumentIDs.contains(doc.id) },
                                        set: { isOn in
                                            if isOn { linkedDocumentIDs.insert(doc.id) }
                                            else { linkedDocumentIDs.remove(doc.id) }
                                        }
                                    )) {
                                        Text(doc.title.isEmpty ? doc.category.displayName : doc.title)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    if let event {
                        WarrantyEventAttachmentSection(
                            event: event,
                            pendingAttachments: $pendingAttachments
                        )
                    }

                    AppPrimaryButton(event == nil ? "Save event" : "Save changes", systemImage: "checkmark.circle.fill") {
                        save()
                    }

                    if event != nil {
                        Button("Delete event", role: .destructive) {
                            if let event { WarrantyStore.delete(event: event, in: modelContext) }
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle(event == nil ? "Add Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let target = event ?? WarrantyStore.createEvent(for: plan, in: modelContext)
        let sortOrder = event?.sortOrder ?? ((plan.events ?? []).map(\.sortOrder).max() ?? 0) + 1
        WarrantyStore.save(
            event: target,
            yearNumber: yearNumber,
            scheduledDate: scheduledDate,
            daysBefore: daysBefore,
            daysAfter: daysAfter,
            serviceType: serviceType,
            requirementDescription: requirementDescription.isEmpty ? serviceType.defaultRequirementDescription : requirementDescription,
            sortOrder: sortOrder,
            isManual: event?.isManual ?? true,
            completedDate: hasCompletedDate ? completedDate : nil,
            linkedDocumentIDs: Array(linkedDocumentIDs),
            linkedMaintenanceID: target.linkedMaintenanceID,
            linkedFaultID: target.linkedFaultID,
            in: modelContext
        )
        if !pendingAttachments.isEmpty {
            MaintenanceAttachmentStore.save(
                drafts: pendingAttachments,
                to: .warrantyEvent(target),
                in: modelContext
            )
        }
        dismiss()
    }
}

private struct WarrantyEventAttachmentSection: View {
    @Environment(\.modelContext) private var modelContext

    let event: WarrantyEvent
    @Binding var pendingAttachments: [MaintenanceAttachmentDraft]

    @State private var showSourceDialog = false
    @State private var showLibraryPicker = false
    @State private var showFileImporter = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        AppSettingsSection("Evidence attachments", caption: "Photos, scans and PDFs saved locally with this event.") {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                if event.attachmentsList.isEmpty && pendingAttachments.isEmpty {
                    Text("No attachments yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppScreenMetrics.controlSpacing) {
                            ForEach(event.attachmentsList) { attachment in
                                VStack(spacing: 4) {
                                    if let image = MaintenanceAttachmentStore.loadThumbnail(for: attachment) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    Text(attachment.displayName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: 72)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        MaintenanceAttachmentStore.delete(attachment, in: modelContext)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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
        .confirmationDialog("Add attachment", isPresented: $showSourceDialog) {
            Button("Choose From Photos") { showLibraryPicker = true }
            Button("Choose From Files") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var drafts: [MaintenanceAttachmentDraft] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let draft = try? MaintenanceAttachmentStore.draft(image: image, fileType: .photo, displayName: "Photo") {
                        drafts.append(draft)
                    }
                }
                await MainActor.run {
                    pendingAttachments.append(contentsOf: drafts)
                    selectedPhotoItems = []
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image, .item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            pendingAttachments.append(contentsOf: urls.compactMap { try? MaintenanceAttachmentStore.draft(fileAt: $0) })
        }
    }
}

private struct WarrantyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "info.circle.fill",
                        title: "About warranty tracking",
                        subtitle: "LoadMate helps you stay organised — it does not guarantee claim acceptance."
                    )
                    WarrantyDisclaimerBanner()
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
            }
            .appScreenBackground()
            .navigationTitle("Warranty Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct WarrantyEvidenceShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pdfData: Data

    private var shareURL: URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Warranty-Evidence-Pack-\(UUID().uuidString).pdf")
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
                Text("Your warranty evidence pack is ready to share or save.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share evidence pack", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius))
                    }
                    .padding(.horizontal)
                } else {
                    Text("Could not prepare the evidence pack for sharing.")
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

private struct WarrantyFaultEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let record: FaultRecord

    @State private var isWarrantyRelated: Bool

    init(profile: VehicleProfile, record: FaultRecord) {
        self.profile = profile
        self.record = record
        _isWarrantyRelated = State(initialValue: record.isWarrantyRelated)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fault") {
                    Text(record.title.isEmpty ? "Untitled fault" : record.title)
                    Text("\(record.severity.displayName) · \(record.status.displayName)")
                        .foregroundStyle(AppColors.textSupporting)
                }
                Section("Warranty") {
                    Toggle("Warranty-related fault", isOn: $isWarrantyRelated)
                }
            }
            .navigationTitle("Warranty Fault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        record.isWarrantyRelated = isWarrantyRelated
                        record.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WarrantyDocumentEditorView: View {
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

    init(profile: VehicleProfile, record: DocumentRecord? = nil) {
        self.profile = profile
        self.record = record
        _title = State(initialValue: record?.title ?? "")
        _category = State(initialValue: record?.category ?? .warranty)
        _dateAdded = State(initialValue: record?.dateAdded ?? Date())
        _hasExpiryDate = State(initialValue: record?.expiryDate != nil)
        _expiryDate = State(initialValue: record?.expiryDate ?? Date())
        _hasReminderDate = State(initialValue: record?.reminderDate != nil)
        _reminderDate = State(initialValue: record?.reminderDate ?? Date())
        _notes = State(initialValue: record?.notes ?? "")
    }

    private var warrantyCategories: [DocumentCategory] {
        [.warranty, .batteryWarranty, .dampReport, .serviceHistory, .purchaseInvoice]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppSettingsSection("Details") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Title", placeholder: "e.g. Year 3 service invoice", text: $title)
                            Picker("Category", selection: $category) {
                                ForEach(warrantyCategories) { option in
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
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
                    }

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
        dismiss()
    }
}
