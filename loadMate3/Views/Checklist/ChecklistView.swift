import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.padTopTabBarActive) private var padTopTabBarActive
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistSection.sortOrder) private var sections: [ChecklistSection]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = ChecklistViewModel()

    @State private var showAddSection = false
    @State private var newSectionTitle = ""

    @State private var sectionPendingRename: ChecklistSection?
    @State private var renameField = ""

    @State private var sectionPendingSubgroup: ChecklistSection?
    @State private var newSubgroupTitle = ""

    @State private var groupPendingRename: ChecklistGroup?
    @State private var subgroupRenameField = ""

    @State private var groupPendingItem: ChecklistGroup?
    @State private var newItemTitle = ""

    @State private var itemPendingRename: ChecklistItem?
    @State private var itemRenameField = ""

    @State private var showResetAllConfirm = false
    @State private var showChecklistHelp = false

    /// Section IDs that are expanded; omitted sections render collapsed (default for new sessions).
    @State private var expandedSectionIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            checklistMain
        }
        .modifier(ChecklistDialogsModifier(
            sections: sections,
            modelContext: modelContext,
            viewModel: viewModel,
            showAddSection: $showAddSection,
            newSectionTitle: $newSectionTitle,
            sectionPendingRename: $sectionPendingRename,
            renameField: $renameField,
            sectionPendingSubgroup: $sectionPendingSubgroup,
            newSubgroupTitle: $newSubgroupTitle,
            groupPendingRename: $groupPendingRename,
            subgroupRenameField: $subgroupRenameField,
            groupPendingItem: $groupPendingItem,
            newItemTitle: $newItemTitle,
            itemPendingRename: $itemPendingRename,
            itemRenameField: $itemRenameField,
            showResetAllConfirm: $showResetAllConfirm
        ))
        .task(id: sections.count) {
            let appState = AppStateStore.resolve(in: modelContext, existing: appStates)
            viewModel.migrateLegacyChecklistIfNeeded(in: modelContext)
            viewModel.ensureSeedData(in: modelContext, existingSections: sections, appState: appState)
        }
    }

    @ViewBuilder
    private var checklistMain: some View {
        Group {
            if sections.isEmpty {
                ContentUnavailableView(
                    "No checklist sections",
                    systemImage: "checklist",
                    description: Text("Add a section to build your towing and pitching checklists. Each section can contain subgroups and checklist items.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if usePadLayout {
                ChecklistPadLayout(
                    sections: sections,
                    viewModel: viewModel,
                    showAddSection: $showAddSection,
                    sectionPendingRename: $sectionPendingRename,
                    renameField: $renameField,
                    sectionPendingSubgroup: $sectionPendingSubgroup,
                    newSubgroupTitle: $newSubgroupTitle,
                    groupPendingRename: $groupPendingRename,
                    subgroupRenameField: $subgroupRenameField,
                    groupPendingItem: $groupPendingItem,
                    newItemTitle: $newItemTitle,
                    itemPendingRename: $itemPendingRename,
                    itemRenameField: $itemRenameField
                )
            } else {
                ScrollView {
                    checklistSectionsList
                }
            }
        }
        .appScreenBackground()
        .modifier(ChecklistNavigationTitleModifier())
        .alert("How to use the checklist", isPresented: $showChecklistHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(checklistHelpMessage)
        }
        .toolbar {
            if !padTopTabBarActive {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showChecklistHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .accessibilityLabel("Checklist help")
                    .pointerHelp("Help")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddSection = true
                            newSectionTitle = ""
                        } label: {
                            Label("Add section", systemImage: "folder.badge.plus")
                        }

                        if !sections.isEmpty {
                            Button(role: .destructive) {
                                showResetAllConfirm = true
                            } label: {
                                Label("Reset entire checklist", systemImage: "arrow.counterclockwise.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Checklist actions")
                }
            }
        }
    }

    @ViewBuilder
    private var checklistSectionsList: some View {
        // VStack: few sections, stable heights — LazyVStack + collapsing cards can confuse scroll layout.
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            ForEach(sections) { section in
                checklistSectionCard(section)
            }
        }
        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
        .padding(.top, AppScreenMetrics.verticalScreenPadding)
        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
    }

    private func checklistSectionCard(_ section: ChecklistSection) -> some View {
        let groups = sortedGroups(for: section)
        let legacy = legacyItems(for: section)
        let isExpanded = expandedSectionIDs.contains(section.id)

        return VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            sectionHeader(section, isExpanded: isExpanded) {
                toggleSectionExpansion(section.id)
            }

            if isExpanded {
                if groups.isEmpty && legacy.isEmpty {
                    Text("Add a subgroup, then add checklist items under it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, AppScreenMetrics.tinySpacing)
                }

                ForEach(groups) { group in
                    checklistSubgroupBlock(section: section, group: group)
                }

                if !legacy.isEmpty {
                    Text("Ungrouped items")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, AppScreenMetrics.tinySpacing)

                    ForEach(Array(legacy.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            AppSectionDivider()
                        }
                        checklistRow(item: item)
                    }
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
                .tint(Color.accentColor)
                .padding(.top, AppScreenMetrics.tinySpacing)
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func toggleSectionExpansion(_ id: UUID) {
        // Do not wrap in withAnimation: animating large subtree insert/remove fights the scroll view
        // (offset / large-title coordinator) and can leave scrolling stuck until the view hierarchy resets.
        var next = expandedSectionIDs
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        expandedSectionIDs = next
    }

    private func checklistSubgroupBlock(section: ChecklistSection, group: ChecklistGroup) -> some View {
        let items = sortedItems(for: group)
        return VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            subgroupHeader(group, sectionTitle: section.title)

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
                Label("Add item", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .tint(Color.accentColor)
            .padding(.top, AppScreenMetrics.tinySpacing)
        }
        .padding(.vertical, AppScreenMetrics.tinySpacing)
        .padding(.horizontal, AppScreenMetrics.smallSpacing)
        .background(
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius * 0.75, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func sortedGroups(for section: ChecklistSection) -> [ChecklistGroup] {
        section.groupsList.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortedItems(for group: ChecklistGroup) -> [ChecklistItem] {
        group.itemsList.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func legacyItems(for section: ChecklistSection) -> [ChecklistItem] {
        section.itemsList.filter { $0.group == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    @ViewBuilder
    private func sectionHeader(_ section: ChecklistSection, isExpanded: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: AppScreenMetrics.smallSpacing) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        .accessibilityHidden(true)

                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .textCase(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(section.title), \(isExpanded ? "expanded" : "collapsed")")
            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand"). Press and hold for rename or delete.")
            .contextMenu {
                sectionManagementActions(section)
            }

            Menu {
                sectionManagementActions(section)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Section options for \(section.title)")
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

    private var checklistHelpMessage: String {
        """
        Tap a circle to check or uncheck an item.

        Tap a section title or chevron to expand or collapse it.

        Press and hold a section title, subgroup title, or item to rename or delete it.

        Use Add subgroup and Add item inside each section to customise your lists.

        Tap … on a section or subgroup for the same options without long press.

        Tap ? (top left) anytime to see this help. Tap … (top right) to add a section or reset the entire checklist.
        """
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

    private func subgroupHeader(_ group: ChecklistGroup, sectionTitle: String) -> some View {
        HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
            Text(group.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityHint("Press and hold for rename or delete.")
                .contextMenu {
                    subgroupManagementActions(group)
                }

            Menu {
                subgroupManagementActions(group)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Subgroup options for \(group.title) in \(sectionTitle)")
        }
    }

    private func checklistRow(item: ChecklistItem) -> some View {
        Button {
            viewModel.setChecked(item, !item.isChecked, in: modelContext)
        } label: {
            HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.green : Color.secondary.opacity(0.55))
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
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
}

private struct ChecklistNavigationTitleModifier: ViewModifier {
    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.padTopTabBarActive) private var padTopTabBarActive

    func body(content: Content) -> some View {
        if padTopTabBarActive {
            content
                .toolbar(.hidden, for: .navigationBar)
        } else if usePadLayout {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            // Inline + principal title avoids scroll glitches with expanding checklist cards.
            content.appPrincipalTabTitle("Checklist")
        }
    }
}

private struct ChecklistDialogsModifier: ViewModifier {
    let sections: [ChecklistSection]
    let modelContext: ModelContext
    let viewModel: ChecklistViewModel

    @Binding var showAddSection: Bool
    @Binding var newSectionTitle: String
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
    @Binding var showResetAllConfirm: Bool

    func body(content: Content) -> some View {
        content
            .alert("Add section", isPresented: $showAddSection) {
                TextField("Section name", text: $newSectionTitle)
                Button("Add") {
                    viewModel.addSection(title: newSectionTitle, in: modelContext, sections: sections)
                    newSectionTitle = ""
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename section", isPresented: Binding(
                get: { sectionPendingRename != nil },
                set: { if !$0 { sectionPendingRename = nil } }
            )) {
                TextField("Section name", text: $renameField)
                Button("Save") {
                    if let section = sectionPendingRename {
                        viewModel.renameSection(section, to: renameField, in: modelContext)
                    }
                    sectionPendingRename = nil
                }
                Button("Cancel", role: .cancel) {
                    sectionPendingRename = nil
                }
            }
            .alert("Add subgroup", isPresented: Binding(
                get: { sectionPendingSubgroup != nil },
                set: { if !$0 { sectionPendingSubgroup = nil } }
            )) {
                TextField("Subgroup name", text: $newSubgroupTitle)
                Button("Add") {
                    if let section = sectionPendingSubgroup {
                        viewModel.addGroup(to: section, title: newSubgroupTitle, in: modelContext)
                    }
                    sectionPendingSubgroup = nil
                    newSubgroupTitle = ""
                }
                Button("Cancel", role: .cancel) {
                    sectionPendingSubgroup = nil
                }
            }
            .alert("Rename subgroup", isPresented: Binding(
                get: { groupPendingRename != nil },
                set: { if !$0 { groupPendingRename = nil } }
            )) {
                TextField("Subgroup name", text: $subgroupRenameField)
                Button("Save") {
                    if let group = groupPendingRename {
                        viewModel.renameGroup(group, to: subgroupRenameField, in: modelContext)
                    }
                    groupPendingRename = nil
                }
                Button("Cancel", role: .cancel) {
                    groupPendingRename = nil
                }
            }
            .alert("Add item", isPresented: Binding(
                get: { groupPendingItem != nil },
                set: { if !$0 { groupPendingItem = nil } }
            )) {
                TextField("Item", text: $newItemTitle)
                Button("Add") {
                    if let group = groupPendingItem {
                        viewModel.addItem(to: group, title: newItemTitle, in: modelContext)
                    }
                    groupPendingItem = nil
                    newItemTitle = ""
                }
                Button("Cancel", role: .cancel) {
                    groupPendingItem = nil
                }
            }
            .alert("Rename item", isPresented: Binding(
                get: { itemPendingRename != nil },
                set: { if !$0 { itemPendingRename = nil } }
            )) {
                TextField("Item name", text: $itemRenameField)
                Button("Save") {
                    if let item = itemPendingRename {
                        viewModel.renameItem(item, to: itemRenameField, in: modelContext)
                    }
                    itemPendingRename = nil
                }
                Button("Cancel", role: .cancel) {
                    itemPendingRename = nil
                }
            }
            .confirmationDialog(
                "Reset all items to unchecked?",
                isPresented: $showResetAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset entire checklist", role: .destructive) {
                    viewModel.resetAll(sections: sections, in: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

#Preview("Checklist") {
    let schema = Schema([ChecklistSection.self, ChecklistGroup.self, ChecklistItem.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ChecklistView()
        .modelContainer(container)
}
