import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistSection.sortOrder) private var sections: [ChecklistSection]

    @StateObject private var viewModel = ChecklistViewModel()

    @State private var showAddSection = false
    @State private var newSectionTitle = ""

    @State private var sectionPendingRename: ChecklistSection?
    @State private var renameField = ""

    @State private var sectionPendingItem: ChecklistSection?
    @State private var newItemTitle = ""

    @State private var showResetAllConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No checklist sections",
                        systemImage: "checklist",
                        description: Text("Add a section to build your towing and pitching checklists.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sections) { section in
                            Section {
                                ForEach(sortedItems(for: section)) { item in
                                    checklistRow(item: item)
                                }
                                .onDelete { indexSet in
                                    deleteItems(at: indexSet, section: section)
                                }

                                Button {
                                    sectionPendingItem = section
                                    newItemTitle = ""
                                } label: {
                                    Label("Add item", systemImage: "plus.circle.fill")
                                        .foregroundStyle(AppColors.blue)
                                }
                            } header: {
                                sectionHeader(section)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .appScreenBackground()
            .navigationTitle("Checklist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
                            .foregroundStyle(AppColors.blue)
                    }
                    .accessibilityLabel("Checklist actions")
                }
            }
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
            .alert("Add item", isPresented: Binding(
                get: { sectionPendingItem != nil },
                set: { if !$0 { sectionPendingItem = nil } }
            )) {
                TextField("Item", text: $newItemTitle)
                Button("Add") {
                    if let section = sectionPendingItem {
                        viewModel.addItem(to: section, title: newItemTitle, in: modelContext)
                    }
                    sectionPendingItem = nil
                    newItemTitle = ""
                }
                Button("Cancel", role: .cancel) {
                    sectionPendingItem = nil
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
        .task(id: sections.count) {
            viewModel.ensureSeedData(in: modelContext, existingSections: sections)
        }
    }

    private func sortedItems(for section: ChecklistSection) -> [ChecklistItem] {
        section.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    @ViewBuilder
    private func sectionHeader(_ section: ChecklistSection) -> some View {
        HStack {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .textCase(nil)
            Spacer()
            Menu {
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
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColors.blue)
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Section options for \(section.title)")
        }
    }

    private func checklistRow(item: ChecklistItem) -> some View {
        Button {
            viewModel.setChecked(item, !item.isChecked, in: modelContext)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? AppColors.green : AppColors.textTertiary)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.isChecked ? "checked" : "unchecked")")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.deleteItem(item, in: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func deleteItems(at offsets: IndexSet, section: ChecklistSection) {
        let ordered = sortedItems(for: section)
        for index in offsets {
            viewModel.deleteItem(ordered[index], in: modelContext)
        }
    }
}

#Preview("Checklist") {
    let schema = Schema([ChecklistSection.self, ChecklistItem.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ChecklistView()
        .modelContainer(container)
}
