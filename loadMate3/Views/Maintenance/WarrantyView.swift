import PDFKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    @State private var showAddFault = false
    @State private var showExportShare = false
    @State private var exportPDFData: Data?
    @State private var selectedEvent: WarrantyEvent?
    @State private var selectedFault: FaultRecord?
    @State private var showRegenerateConfirm = false

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(
            profiles: profiles,
            appState: AppStateStore.canonical(from: appStates)
        )
    }

    private var insuranceSyncToken: String {
        guard let profile = activeProfile else { return "none" }
        let dateToken = profile.insuranceStartDate.map { String(Int($0.timeIntervalSince1970)) } ?? "nil"
        return "\(profile.id.uuidString)-\(dateToken)"
    }

    private var activePlan: WarrantyPlan? {
        guard let profile = activeProfile else { return nil }
        return WarrantySupport.plan(for: profile.id, from: warrantyPlans)
    }

    private var planEvents: [WarrantyEvent] {
        activePlan?.eventsList ?? []
    }

    private var scopedDocuments: [DocumentRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.documentRecords(for: profile.id, from: documentRecords)
    }

    private var scopedFaults: [FaultRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.faultRecords(for: profile.id, from: faultRecords)
    }

    private var scopedMaintenance: [MaintenanceRecord] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.maintenanceRecords(for: profile.id, from: maintenanceRecords)
    }

    private var warrantyItems: [FaultRecord] {
        WarrantySupport.warrantyFaults(from: scopedFaults, events: planEvents)
    }

    private var otherFaults: [FaultRecord] {
        WarrantySupport.unflaggedFaults(from: scopedFaults, events: planEvents)
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
            .appPrincipalTabTitle("Service & warranty")
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showSetup) {
            if let profile = activeProfile {
                WarrantyPlanEditorSheet(profile: profile, plan: nil) {
                    if let plan = activePlan {
                        WarrantyStore.generateAnnualEvents(
                            plan: plan,
                            in: modelContext,
                            kind: profile.kind,
                            ukMarket: profile.warrantyUKMarket
                        )
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
        .sheet(isPresented: $showAddFault) {
            if let profile = activeProfile {
                FaultRecordEditorView(
                    profile: profile,
                    maintenanceRecords: scopedMaintenance,
                    defaultWarrantyRelated: true
                )
            }
        }
        .sheet(item: $selectedFault) { record in
            if let profile = activeProfile {
                FaultRecordEditorView(
                    profile: profile,
                    record: record,
                    maintenanceRecords: scopedMaintenance,
                    defaultWarrantyRelated: true,
                    suggestAsWarrantyItem: otherFaults.contains(where: { $0.id == record.id })
                )
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let exportPDFData {
                WarrantyEvidenceShareSheet(pdfData: exportPDFData)
            }
        }
        .task(id: insuranceSyncToken) {
            if let profile = activeProfile {
                WarrantyStore.syncInsuranceRenewalEvents(for: profile, in: modelContext)
            }
        }
        .confirmationDialog(
            "Regenerate auto events?",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("Regenerate annual events") {
                if let plan = activePlan, let profile = activeProfile {
                    WarrantyStore.generateAnnualEvents(
                        plan: plan,
                        in: modelContext,
                        kind: profile.kind,
                        ukMarket: profile.warrantyUKMarket,
                        replaceAutoGenerated: true
                    )
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
                    Button("Add service event", systemImage: "plus") { showAddEvent = true }
                    Button("Add warranty item", systemImage: "exclamationmark.triangle") { showAddFault = true }
                    Button("Edit plan", systemImage: "pencil") { showEditPlan = true }
                    Button("Export evidence pack", systemImage: "square.and.arrow.up") { exportEvidencePack() }
                    Button("About service & warranty", systemImage: "info.circle") { showInfo = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Service and warranty actions")
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
                WarrantyDisclaimerInfoButton { showInfo = true }
                VehicleLookupSummarySection(profile: profile)

                AppSettingsSection("Get started", caption: "Build one continuous service timeline for this vehicle — warranty cover is optional.") {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                        Text("Log annual services and inspections whether a manufacturer is paying or you are. If cover is later refused or expires, the same timeline continues.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSupporting)
                        AppPrimaryButton("Set up service timeline", systemImage: "calendar.badge.plus") {
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
                WarrantyCoverageBanner(plan: plan)
                VehicleLookupSummarySection(profile: profile)
                WarrantyDisclaimerInfoButton { showInfo = true }

                AppSettingsSection(
                    "Service timeline",
                    caption: "Tap a service to edit. Insurance rows use the switch when done."
                ) {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        WarrantyTimelineView(
                            plan: plan,
                            events: plan.eventsList,
                            onSelectEvent: { selectedEvent = $0 }
                        )
                        AppSecondaryButton("Add service event") {
                            showAddEvent = true
                        }
                    }
                }

                warrantyItemsSection
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            .padReadableContent(maxWidth: usePadLayout ? 960 : PadContentLayout.readableMaxWidth)
        }
    }

    private var warrantyItemsSection: some View {
        AppSettingsSection(
            "Warranty items",
            caption: "Issues you are treating as warranty claims. Open or completed — separate from the service timeline."
        ) {
            if warrantyItems.isEmpty && otherFaults.isEmpty {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    Text("No warranty items yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                    AppSecondaryButton("Add warranty item") {
                        showAddFault = true
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(warrantyItems) { record in
                        Button { selectedFault = record } label: {
                            warrantyRow(
                                title: record.title.isEmpty ? "Untitled item" : record.title,
                                subtitle: warrantyItemSubtitle(for: record),
                                systemImage: record.status.isResolved
                                    ? "checkmark.seal.fill"
                                    : "exclamationmark.triangle.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !otherFaults.isEmpty {
                        Text("Other faults (not warranty items)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSupporting)
                            .padding(.top, warrantyItems.isEmpty ? 0 : 4)

                        ForEach(otherFaults) { record in
                            Button { selectedFault = record } label: {
                                warrantyRow(
                                    title: record.title.isEmpty ? "Untitled fault" : record.title,
                                    subtitle: "Turn on Warranty item · \(record.status.displayName)",
                                    systemImage: "exclamationmark.triangle"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    AppSecondaryButton("Add warranty item") {
                        showAddFault = true
                    }
                }
            }
        }
    }

    private func warrantyItemSubtitle(for record: FaultRecord) -> String {
        var parts = [record.status.displayName, record.severity.displayName]
        if record.status.isResolved, let resolved = record.resolvedDate {
            parts.append("Resolved \(Formatters.date(resolved))")
        } else {
            parts.append("Found \(Formatters.date(record.discoveredDate))")
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
        exportPDFData = WarrantyEvidencePackBuilder.buildPDF(
            input: .init(
                plan: plan,
                events: plan.eventsList,
                documents: scopedDocuments,
                maintenanceRecords: scopedMaintenance,
                faults: scopedFaults
            )
        )
        showExportShare = true
    }
}

// MARK: - Banner & timeline components

struct WarrantyDisclaimerInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: "info.circle")
                    .font(.body.weight(.medium))
                Text("About service & warranty")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
            .padding(.vertical, 12)
            .background(LyneqoTheme.softTeal)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About service and warranty")
        .accessibilityHint("Shows how the service timeline relates to warranty cover")
    }
}

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
        .background(LyneqoTheme.softTeal)
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
                let isLast = index == events.count - 1
                if event.serviceType == .insuranceRenewal {
                    WarrantyTimelineInsuranceRow(event: event, isLast: isLast)
                } else {
                    Button { onSelectEvent(event) } label: {
                        WarrantyTimelineEventRow(
                            event: event,
                            events: events,
                            isLast: isLast
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct WarrantyTimelineInsuranceRow: View {
    @Environment(\.modelContext) private var modelContext

    let event: WarrantyEvent
    let isLast: Bool

    private var isDone: Binding<Bool> {
        Binding(
            get: { event.completedDate != nil },
            set: { done in
                event.completedDate = done ? (event.completedDate ?? Date()) : nil
                event.updatedAt = Date()
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(event.completedDate != nil ? AppColors.green : Color.secondary.opacity(0.85))
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

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Insurance")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(Formatters.date(event.scheduledDate))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                    Toggle("Done", isOn: isDone)
                        .labelsHidden()
                        .tint(AppColors.green)
                        .accessibilityLabel("Insurance done")
                }

                Text(event.requirementText)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : AppScreenMetrics.sectionSpacing)
        }
        .accessibilityElement(children: .contain)
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
                        .fill(LyneqoTheme.border)
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
    let events: [WarrantyEvent]
    let isLast: Bool

    private var status: WarrantyEventStatus {
        WarrantySupport.status(for: event, among: events)
    }

    private var isImportantMilestone: Bool {
        event.isImportantMilestone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                timelineMarker
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
                    Text(event.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isImportantMilestone ? AppColors.purple : Color.primary)
                    Spacer(minLength: 8)
                    Text(WarrantySupport.statusDisplayName(for: status))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }

                if isImportantMilestone {
                    Text("Important year — complete on or before the purchase anniversary")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.purple)
                        .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(isImportantMilestone ? AppColors.purple.opacity(0.9) : AppColors.textSupporting)

                if !event.attachmentsList.isEmpty || !event.linkedDocumentIDs.isEmpty {
                    Text("\(event.attachmentsList.count + event.linkedDocumentIDs.count) evidence item(s)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.purple)
                }
            }
            .padding(.bottom, isLast ? 0 : AppScreenMetrics.sectionSpacing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    @ViewBuilder
    private var timelineMarker: some View {
        if isImportantMilestone {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.purple)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .frame(width: 16, height: 16)
        }
    }

    private var accessibilityLabel: String {
        var parts = [event.displayTitle, WarrantySupport.statusDisplayName(for: status)]
        if isImportantMilestone {
            parts.insert("Important year", at: 0)
        }
        return parts.joined(separator: ", ")
    }

    private var statusColor: Color {
        switch status {
        case .completed: return AppColors.green
        case .inWindow: return .accentColor
        case .overdue: return AppColors.red
        case .upcoming: return Color.secondary
        case .planned: return Color.secondary.opacity(0.85)
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
    @State private var selectedMOTClass: UKMotorhomeMOTClass
    @State private var showInfo = false
    @State private var showMOTClassInfo = false

    init(profile: VehicleProfile, plan: WarrantyPlan?, onSaved: (() -> Void)? = nil) {
        self.profile = profile
        self.plan = plan
        self.onSaved = onSaved
        _isUnderWarranty = State(initialValue: plan?.isUnderWarranty ?? true)
        _hasExpiryDate = State(initialValue: plan?.warrantyExpiryDate != nil)
        _warrantyExpiryDate = State(initialValue: plan?.warrantyExpiryDate ?? Date())
        _manufacturer = State(initialValue: Self.initialManufacturer(plan: plan, profile: profile))
        _modelYearText = State(initialValue: Self.initialModelYearText(plan: plan, profile: profile))
        _purchaseDate = State(initialValue: plan?.purchaseDate ?? Date())
        _purchaseCondition = State(initialValue: plan?.purchaseCondition ?? .newPurchase)
        _ownershipType = State(initialValue: plan?.ownershipType ?? .original)
        _warrantyType = State(initialValue: plan?.warrantyType ?? "")
        _durationYears = State(initialValue: plan?.durationYears ?? WarrantySupport.defaultDurationYears)
        _handbookNotes = State(initialValue: plan?.handbookNotes ?? "")
        _selectedTemplateID = State(initialValue: plan?.templateID ?? WarrantySupport.customTemplateID)
        _selectedMOTClass = State(
            initialValue: plan?.motClass ?? WarrantySupport.suggestedMOTClass(for: profile)
        )
    }

    private func applyPatternDefaults(patternID: String) {
        let pattern = WarrantySupport.patternOrCustom(id: patternID, kind: profile.kind)
        durationYears = pattern.durationYears
        if !pattern.manufacturerName.isEmpty {
            manufacturer = pattern.manufacturerName
        }
    }

    private var availableTemplates: [WarrantyManufacturerTemplate] {
        WarrantySupport.pickerOptions(for: profile)
    }

    private var usesUKStarters: Bool {
        WarrantySupport.usesUKManufacturerStarters(for: profile)
    }

    private var selectedPattern: WarrantyManufacturerTemplate {
        WarrantySupport.patternOrCustom(id: selectedTemplateID, kind: profile.kind)
    }

    private var showsUKMOTClassPicker: Bool {
        profile.kind == .motorhome && profile.warrantyUKMarket
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "shield.fill",
                        title: plan == nil ? "Service timeline setup" : "Edit service plan",
                        subtitle: "One continuous record of services for this \(profile.kind.displayName.lowercased()). Warranty cover is optional."
                    )

                    WarrantyDisclaimerInfoButton { showInfo = true }

                    AppSettingsSection("Coverage") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            Toggle("Manufacturer or dealer may pay for services", isOn: $isUnderWarranty)
                            Text(isUnderWarranty
                                ? "Services still belong on the timeline. This only records that cover may pay for them."
                                : "Same services still need doing. Keep logging them on the timeline for your records and when selling.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .fixedSize(horizontal: false, vertical: true)
                            Toggle("Set explicit expiry date", isOn: $hasExpiryDate)
                            if hasExpiryDate {
                                DatePicker("Warranty expires", selection: $warrantyExpiryDate, displayedComponents: .date)
                            }
                        }
                    }

                    AppSettingsSection(
                        usesUKStarters ? "Manufacturer starter" : "Custom plan",
                        caption: usesUKStarters
                            ? "UK / NI starter schedules only — confirm with your handbook. Change market in Settings if this vehicle was sold outside the UK."
                            : "Manufacturer starters are for the UK / Northern Ireland market. Build your own schedule from your local handbook, then edit each event."
                    ) {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            if usesUKStarters {
                                Picker("Manufacturer", selection: $selectedTemplateID) {
                                    ForEach(availableTemplates) { option in
                                        Text(option.displayName).tag(option.id)
                                    }
                                }

                                Text(selectedPattern.summary)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(WarrantySupport.starterDisclaimer)
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Custom plan — set duration and edit each year’s window and requirements after creation.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .onChange(of: selectedTemplateID) { _, newValue in
                        applyPatternDefaults(patternID: newValue)
                    }
                    .onAppear {
                        if !usesUKStarters {
                            selectedTemplateID = WarrantySupport.customTemplateID
                        } else if !availableTemplates.contains(where: { $0.id == selectedTemplateID }) {
                            selectedTemplateID = WarrantySupport.customTemplateID
                        }
                    }

                    if showsUKMOTClassPicker {
                        AppSettingsSection(
                            "UK MOT class",
                            caption: "Drives when statutory tests are added to the timeline. Suggested from plated MAM when available — confirm with your V5C."
                        ) {
                            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                                HStack(alignment: .center, spacing: AppScreenMetrics.smallSpacing) {
                                    Picker("MOT class", selection: $selectedMOTClass) {
                                        ForEach(UKMotorhomeMOTClass.allCases) { option in
                                            Text(option.displayName).tag(option)
                                        }
                                    }

                                    Button {
                                        showMOTClassInfo = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(Color.secondary)
                                            .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("About MOT types")
                                    .accessibilityHint("Explains Class 4, Class 7, and HGV annual tests")
                                }

                                Text(selectedMOTClass.summary)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("First test: year \(selectedMOTClass.firstTestYear), then annually.")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSupporting)
                            }
                        }
                    }

                    if VehicleLookupDisplay.hasSummary(for: profile) {
                        VehicleLookupSummarySection(profile: profile)
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
                            if ownershipType == .subsequent {
                                Text("Subsequent ownership can change remaining cover. Check your handbook and adjust duration yourself.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            AppLabeledTextField("Warranty type", placeholder: "e.g. Structural", text: $warrantyType)
                            Stepper("Duration: \(durationYears) years", value: $durationYears, in: 1...20)
                        }
                    }

                    AppSettingsSection("Handbook notes") {
                        TextEditor(text: $handbookNotes)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(LyneqoTheme.card)
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
            .navigationTitle(plan == nil ? "Set Up Timeline" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showInfo) {
                WarrantyInfoSheet()
            }
            .sheet(isPresented: $showMOTClassInfo) {
                MOTClassInfoSheet()
            }
        }
    }

    private static func initialManufacturer(plan: WarrantyPlan?, profile: VehicleProfile) -> String {
        let existing = plan?.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existing.isEmpty { return existing }
        return profile.manufacturer
    }

    private static func initialModelYearText(plan: WarrantyPlan?, profile: VehicleProfile) -> String {
        if let year = plan?.modelYear { return String(year) }
        if let year = profile.firstRegistrationYear { return String(year) }
        return ""
    }

    private func save() {
        let target = plan ?? WarrantyStore.createPlan(for: profile.id, in: modelContext)
        let modelYear = Int(modelYearText.trimmingCharacters(in: .whitespacesAndNewlines))
        let templateID: String? = {
            guard usesUKStarters else { return nil }
            return selectedTemplateID == WarrantySupport.customTemplateID ? nil : selectedTemplateID
        }()
        let template = WarrantySupport.patternOrCustom(id: templateID, kind: profile.kind)
        let resolvedManufacturer: String = {
            let typed = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typed.isEmpty { return typed }
            return template.manufacturerName
        }()
        WarrantyStore.save(
            plan: target,
            isUnderWarranty: isUnderWarranty,
            warrantyExpiryDate: hasExpiryDate ? warrantyExpiryDate : nil,
            manufacturer: resolvedManufacturer,
            modelYear: modelYear,
            purchaseDate: purchaseDate,
            purchaseCondition: purchaseCondition,
            ownershipType: ownershipType,
            warrantyType: warrantyType,
            durationYears: durationYears,
            handbookNotes: handbookNotes,
            templateID: templateID,
            motClass: showsUKMOTClassPicker ? selectedMOTClass : nil,
            in: modelContext
        )
        WarrantyStore.syncInsuranceRenewalEvents(for: profile, in: modelContext)
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

    @State private var scheduledDate: Date
    @State private var daysBefore: Int
    @State private var daysAfter: Int
    @State private var serviceType: WarrantyServiceType
    @State private var requirementDescription: String
    @State private var hasCompletedDate: Bool
    @State private var completedDate: Date
    @State private var linkedDocumentIDs: Set<UUID>
    @State private var pendingAttachments: [MaintenanceAttachmentDraft] = []
    @State private var repeatYearly = false

    init(plan: WarrantyPlan, event: WarrantyEvent?, documents: [DocumentRecord]) {
        self.plan = plan
        self.event = event
        self.documents = documents
        _scheduledDate = State(initialValue: event?.scheduledDate ?? Date())
        _daysBefore = State(initialValue: event?.daysBefore ?? WarrantySupport.defaultDaysBefore)
        _daysAfter = State(initialValue: event?.daysAfter ?? WarrantySupport.defaultDaysAfter)
        _serviceType = State(initialValue: event?.serviceType ?? .normalService)
        _requirementDescription = State(initialValue: event?.requirementDescription ?? "")
        _hasCompletedDate = State(initialValue: event?.completedDate != nil)
        _completedDate = State(initialValue: event?.completedDate ?? Date())
        _linkedDocumentIDs = State(initialValue: Set(event?.linkedDocumentIDs ?? []))
    }

    private var derivedYearNumber: Int {
        WarrantySupport.yearNumber(for: scheduledDate, purchaseDate: plan.purchaseDate)
    }

    private var yearLabelText: String {
        if derivedYearNumber > 0 {
            return "Year \(derivedYearNumber) (from due date vs purchase)"
        }
        return "Custom event (due date is not a clear service year from purchase)"
    }

    private var repeatCaption: String {
        let end = WarrantySupport.yearlyRepeatEndDate(for: plan, startingFrom: scheduledDate)
        let count = WarrantySupport.yearlyOccurrenceDates(from: scheduledDate, through: end).count
        return "Adds matching events each year from this due date through \(Formatters.date(end)) (\(count) in total, skipping any that already exist)."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "calendar.badge.clock",
                        title: event == nil ? "New service event" : "Edit service event",
                        subtitle: "Set the due date, action window, and what work is required."
                    )

                    AppSettingsSection("Schedule") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            DatePicker("Due date", selection: $scheduledDate, displayedComponents: .date)
                            Text(yearLabelText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textSupporting)
                            Stepper("Days before: \(daysBefore)", value: $daysBefore, in: 0...365)
                            Stepper("Days after: \(daysAfter)", value: $daysAfter, in: 0...365)
                            Toggle("Repeat yearly", isOn: $repeatYearly)
                            if repeatYearly {
                                Text(repeatCaption)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                                .background(LyneqoTheme.card)
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
        let requirement = requirementDescription.isEmpty
            ? serviceType.defaultRequirementDescription
            : requirementDescription
        WarrantyStore.save(
            event: target,
            yearNumber: derivedYearNumber,
            scheduledDate: scheduledDate,
            daysBefore: daysBefore,
            daysAfter: daysAfter,
            serviceType: serviceType,
            requirementDescription: requirement,
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
        if repeatYearly {
            WarrantyStore.ensureYearlyRepeats(for: plan, matching: target, in: modelContext)
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
                                WarrantyAttachmentThumbnail(
                                    title: attachment.displayName,
                                    image: MaintenanceAttachmentStore.loadThumbnail(for: attachment),
                                    symbolName: symbolName(for: attachment.fileType)
                                ) {
                                    MaintenanceAttachmentStore.delete(attachment, in: modelContext)
                                }
                            }

                            ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, draft in
                                WarrantyAttachmentThumbnail(
                                    title: draft.displayName,
                                    image: draft.thumbnailImage ?? previewImage(for: draft),
                                    symbolName: symbolName(for: draft.fileType)
                                ) {
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

    private func previewImage(for draft: MaintenanceAttachmentDraft) -> UIImage? {
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

private struct WarrantyAttachmentThumbnail: View {
    let title: String
    let image: UIImage?
    let symbolName: String
    let onDelete: () -> Void

    var body: some View {
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
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(title)
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
                        title: "About service & warranty",
                        subtitle: "One timeline for the life of the vehicle. Warranty is optional cover for the same services."
                    )
                    Text("Whether a manufacturer pays or you do, annual services, inspections and repairs belong on this timeline. If cover expires or a claim is refused, keep logging the same work — it remains useful when you sell.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                    WarrantyDisclaimerBanner()
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
            }
            .appScreenBackground()
            .navigationTitle("Service & warranty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct MOTClassInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "info.circle.fill",
                        title: "UK MOT types",
                        subtitle: "Choose the class that matches your motorhome’s plated mass and body type. Always confirm with your V5C and test station."
                    )

                    ForEach(UKMotorhomeMOTClass.allCases) { motClass in
                        AppGroupedCard {
                            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                                Text(motClass.displayName)
                                    .font(.headline.weight(.semibold))
                                Text(motClass.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("First test: year \(motClass.firstTestYear), then annually.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                            }
                        }
                    }

                    Text("Lyneqo suggests a class from plated MAM when available, but some vehicles in the 3,000–3,500 kg band remain Class 4 depending on body type. Edit the class if your handbook or test station says otherwise.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("MOT types")
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
