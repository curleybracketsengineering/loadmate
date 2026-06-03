import SwiftUI
import SwiftData

/// iPad checklist — sidebar section list with detail panel for the selected group.
struct ChecklistPadLayout: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    let sections: [ChecklistSection]
    let viewModel: ChecklistViewModel

    @Binding var showAddSection: Bool
    @Binding var sectionPendingRename: ChecklistSection?
    @Binding var renameField: String
    @Binding var sectionPendingSubgroup: ChecklistSection?
    @Binding var newSubgroupTitle: String
    @Binding var groupPendingRename: ChecklistGroup?
    @Binding var subgroupRenameField: String
    @Binding var groupPendingItem: ChecklistGroup?
    @Binding var newItemTitle: String
    @Binding var itemPendingRename: ChecklistItem?
    @Binding var itemRenameField: String

    @State private var selectedSectionID: UUID?
    @State private var expandedGroupIDs: Set<UUID> = []

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: appStates.first)
    }

    private var profileTrips: [Trip] {
        TripStore.sortedTrips(for: activeProfile)
    }

    private var activeTrip: Trip? {
        TripStore.activeTrip(for: activeProfile)
    }

    private var selectedSection: ChecklistSection? {
        guard let selectedSectionID else { return sections.first }
        return sections.first { $0.id == selectedSectionID } ?? sections.first
    }

    private var overallCounts: (completed: Int, total: Int) {
        ChecklistProgress.overall(in: sections)
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: PadContentLayout.horizontalGutter)

            HStack(alignment: .top, spacing: AppScreenMetrics.sectionSpacing) {
                sidebar
                    .frame(width: 340)

                detailPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: 1_120, maxHeight: .infinity, alignment: .topLeading)

            Spacer(minLength: PadContentLayout.horizontalGutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, AppScreenMetrics.verticalScreenPadding)
        .onAppear {
            syncSelection(with: sections)
        }
        .onChange(of: sections.map(\.id)) { _, _ in
            syncSelection(with: sections)
        }
        .onChange(of: selectedSectionID) { _, newValue in
            guard let section = sections.first(where: { $0.id == newValue }) else { return }
            expandedGroupIDs = Set(sortedGroups(for: section).map(\.id))
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                Text("Checklist")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.primary)

                overallProgressCard

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    ForEach(sections) { section in
                        sectionSidebarRow(section)
                    }
                }

                Button {
                    showAddSection = true
                } label: {
                    Label("Add checklist group", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .tint(AppColors.blue)
                .padding(.top, AppScreenMetrics.tinySpacing)
            }
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var overallProgressCard: some View {
        let counts = overallCounts
        let fraction = ChecklistProgress.fraction(completed: counts.completed, total: counts.total)
        let percent = ChecklistProgress.percent(completed: counts.completed, total: counts.total)

        return VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            HStack(alignment: .center, spacing: AppScreenMetrics.fieldSpacing) {
                ChecklistProgressRing(completed: counts.completed, total: counts.total)

                VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                    Text("Overall progress")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("\(counts.completed) of \(counts.total) complete")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    ChecklistLinearProgressBar(fraction: fraction)
                    Text("\(percent)%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.blue)
                }
            }

            tripRow
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(cardBackground)
    }

    @ViewBuilder
    private var tripRow: some View {
        if let profile = activeProfile {
            Menu {
                ForEach(profileTrips) { trip in
                    Button {
                        TripStore.setActive(trip, on: profile, in: modelContext)
                    } label: {
                        if trip.id == activeTrip?.id {
                            Label(trip.name, systemImage: "checkmark")
                        } else {
                            Text(trip.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: AppScreenMetrics.smallSpacing) {
                    Image(systemName: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.blue)
                    Text("Trip: \(activeTrip?.name ?? "None")")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, AppScreenMetrics.controlSpacing)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trip, \(activeTrip?.name ?? "None")")
            .accessibilityHint("Shows trips for this vehicle")
        }
    }

    private func sectionSidebarRow(_ section: ChecklistSection) -> some View {
        let style = ChecklistPresentation.sectionStyle(for: section.title)
        let counts = ChecklistProgress.counts(in: section)
        let isSelected = section.id == selectedSection?.id

        return Button {
            selectedSectionID = section.id
        } label: {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                ChecklistIconBadge(systemImage: style.systemImage, tint: style.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    Text("\(counts.completed) / \(counts.total) complete")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .rotationEffect(.degrees(isSelected ? 0 : 90))
                    .accessibilityHidden(true)
            }
            .padding(AppScreenMetrics.cardInteriorPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .fill(isSelected ? AppColors.blue.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? AppColors.blue.opacity(0.55) : Color(.separator).opacity(0.35), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            sectionManagementActions(section)
        }
        .accessibilityLabel("\(section.title), \(counts.completed) of \(counts.total) complete")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPanel: some View {
        if let section = selectedSection {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    sectionDetailHeader(section)

                    let groups = sortedGroups(for: section)
                    let legacy = legacyItems(for: section)

                    if groups.isEmpty && legacy.isEmpty {
                        Text("Add a subgroup, then add checklist items under it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(groups) { group in
                        groupDetailCard(section: section, group: group)
                    }

                    if !legacy.isEmpty {
                        legacyDetailCard(section: section, items: legacy)
                    }

                    Button {
                        sectionPendingSubgroup = section
                        newSubgroupTitle = ""
                    } label: {
                        Label("Add subgroup", systemImage: "folder.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .tint(AppColors.blue)
                }
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .scrollIndicators(.hidden)
        } else {
            ContentUnavailableView(
                "Select a checklist group",
                systemImage: "checklist",
                description: Text("Choose a group on the left to view its items.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sectionDetailHeader(_ section: ChecklistSection) -> some View {
        let style = ChecklistPresentation.sectionStyle(for: section.title)
        let counts = ChecklistProgress.counts(in: section)

        return HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            ChecklistIconBadge(systemImage: style.systemImage, tint: style.tint)

            VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                Text(section.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.primary)
                if let summary = style.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: AppScreenMetrics.controlSpacing)

            HStack(spacing: AppScreenMetrics.smallSpacing) {
                Text("\(counts.completed)/\(counts.total) complete")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.blue.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))

                Menu {
                    sectionManagementActions(section)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.blue)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .accessibilityLabel("Section options for \(section.title)")
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(cardBackground)
    }

    private func groupDetailCard(section: ChecklistSection, group: ChecklistGroup) -> some View {
        let items = sortedItems(for: group)
        let style = ChecklistPresentation.groupStyle(for: group.title)
        let counts = ChecklistProgress.counts(in: group)
        let isExpanded = expandedGroupIDs.contains(group.id)

        return VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Button {
                toggleGroupExpansion(group.id)
            } label: {
                HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                    ChecklistIconBadge(systemImage: style.systemImage, tint: AppColors.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        if let summary = style.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    Text("\(counts.completed)/\(counts.total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                subgroupManagementActions(group)
            }

            if isExpanded {
                if items.isEmpty {
                    Text("No items yet — tap Add item below.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        AppSectionDivider()
                    }
                    checklistRow(item: item)
                }

                Button {
                    groupPendingItem = group
                    newItemTitle = ""
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .tint(AppColors.blue)
                .padding(.top, AppScreenMetrics.tinySpacing)
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(cardBackground)
    }

    private func legacyDetailCard(section: ChecklistSection, items: [ChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Ungrouped items")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    AppSectionDivider()
                }
                checklistRow(item: item)
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(cardBackground)
    }

    // MARK: - Rows & actions

    private func checklistRow(item: ChecklistItem) -> some View {
        Button {
            viewModel.setChecked(item, !item.isChecked, in: modelContext)
        } label: {
            HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? AppColors.blue : Color.secondary.opacity(0.55))
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.body)
                    .foregroundStyle(item.isChecked ? Color.secondary : Color.primary)
                    .strikethrough(item.isChecked, color: Color.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, AppScreenMetrics.tinySpacing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.isChecked ? "checked" : "unchecked")")
        .accessibilityHint("Press and hold for rename or delete.")
        .contextMenu {
            Button {
                itemPendingRename = item
                itemRenameField = item.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.deleteItem(item, in: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func sectionManagementActions(_ section: ChecklistSection) -> some View {
        Button {
            sectionPendingRename = section
            renameField = section.title
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            viewModel.resetSection(section, in: modelContext)
        } label: {
            Label("Reset section", systemImage: "arrow.counterclockwise")
        }
        Button(role: .destructive) {
            viewModel.deleteSection(section, in: modelContext)
        } label: {
            Label("Delete section", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func subgroupManagementActions(_ group: ChecklistGroup) -> some View {
        Button {
            groupPendingRename = group
            subgroupRenameField = group.title
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            viewModel.deleteGroup(group, in: modelContext)
        } label: {
            Label("Delete subgroup", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
            }
    }

    private func syncSelection(with sections: [ChecklistSection]) {
        guard !sections.isEmpty else {
            selectedSectionID = nil
            expandedGroupIDs = []
            return
        }
        if let selectedSectionID, sections.contains(where: { $0.id == selectedSectionID }) {
            return
        }
        selectedSectionID = sections.first?.id
        if let first = sections.first {
            expandedGroupIDs = Set(sortedGroups(for: first).map(\.id))
        }
    }

    private func toggleGroupExpansion(_ id: UUID) {
        var next = expandedGroupIDs
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        expandedGroupIDs = next
    }

    private func sortedGroups(for section: ChecklistSection) -> [ChecklistGroup] {
        section.groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortedItems(for group: ChecklistGroup) -> [ChecklistItem] {
        group.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func legacyItems(for section: ChecklistSection) -> [ChecklistItem] {
        section.items.filter { $0.group == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }
}
