import SwiftUI
import SwiftData

enum CareDestination: Hashable {
    case maintenance
    case tyreSafety
    case warranty
    case documents
    case checklist
}

struct CareView: View {
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query private var documentRecords: [DocumentRecord]
    @Query private var faultRecords: [FaultRecord]
    @Query private var warrantyPlans: [WarrantyPlan]
    @Query(sort: \ChecklistSection.sortOrder) private var checklistSections: [ChecklistSection]

    @Binding var pendingDestination: CareDestination?
    @State private var destination: CareDestination?

    init(pendingDestination: Binding<CareDestination?> = .constant(nil)) {
        _pendingDestination = pendingDestination
    }

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

    private var maintenanceSummary: MaintenanceDashboardSummary {
        MaintenanceSupport.dashboardSummary(
            maintenanceRecords: scopedMaintenance,
            documents: scopedDocuments,
            faults: scopedFaults
        )
    }

    private var reminderItems: [MaintenanceReminderItem] {
        guard let profile = activeProfile else { return [] }
        return MaintenanceSupport.reminderItems(
            maintenanceRecords: scopedMaintenance,
            documents: scopedDocuments,
            warrantyPlans: warrantyPlans,
            vehicleID: profile.id,
            warrantyAvailable: profile.warrantyAvailable
        )
    }

    private var checklistCounts: (completed: Int, total: Int) {
        ChecklistProgress.overall(in: checklistSections)
    }

    var body: some View {
        if usePadLayout {
            CarePadView()
        } else {
            phoneBody
        }
    }

    private var phoneBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    careHubCard(
                        title: "Maintenance",
                        subtitle: maintenanceSubtitle,
                        systemImage: "wrench.and.screwdriver.fill",
                        tint: AppColors.blue
                    ) { destination = .maintenance }

                    if WarrantySupport.showsWarrantyFeatures(for: activeProfile) {
                        careHubCard(
                            title: "Warranty",
                            subtitle: warrantySubtitle,
                            systemImage: "shield.fill",
                            tint: AppColors.purple
                        ) { destination = .warranty }
                    }

                    careHubCard(
                        title: "Documents",
                        subtitle: "\(scopedDocuments.count) files. Insurance, Registration, Manuals & more.",
                        systemImage: "folder.fill",
                        tint: AppColors.orange
                    ) { destination = .documents }

                    careHubCard(
                        title: "Checklist",
                        subtitle: "\(checklistCounts.total) items. Pre-trip & setup checklist.",
                        systemImage: "checklist",
                        tint: AppColors.blue
                    ) { destination = .checklist }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Care")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: pendingDestination) { _, newValue in
                guard let newValue else { return }
                destination = newValue
                pendingDestination = nil
            }
            .navigationDestination(item: $destination) { dest in
                switch dest {
                case .maintenance:
                    MaintenanceView()
                case .tyreSafety:
                    TyreSafetyView()
                case .warranty:
                    WarrantyView()
                case .documents:
                    MaintenanceView()
                case .checklist:
                    ChecklistView()
                }
            }
        }
    }

    private var maintenanceSubtitle: String {
        let dueSoon = reminderItems.filter { $0.kind == .maintenance }.prefix(2).count
        if dueSoon > 0, let next = reminderItems.first(where: { $0.kind == .maintenance }) {
            return "\(dueSoon) items due soon. Next: \(next.title)."
        }
        return maintenanceSummary.upcomingSubtitle
    }

    private var warrantySubtitle: String {
        guard let profile = activeProfile else {
            return "Plans, checks and documents."
        }
        return WarrantySupport.careHubSubtitle(plans: warrantyPlans, vehicleID: profile.id)
    }

    private func careHubCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .multilineTextAlignment(.leading)
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
        }
        .buttonStyle(.plain)
    }
}
