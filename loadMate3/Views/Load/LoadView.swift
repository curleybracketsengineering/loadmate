import SwiftUI
import SwiftData

struct LoadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LibraryItem.name)]) private var libraryItems: [LibraryItem]
    @Query private var loadedItems: [LoadedItem]
    @Query private var configs: [SetupConfig]

    @StateObject private var viewModel = LoadViewModel()
    @State private var showAddItem = false
    @State private var newName = ""
    @State private var newWeight = ""

    private var setupConfig: SetupConfig? { configs.first }

    private var showCaravanSetupBanner: Bool {
        guard let config = setupConfig else { return true }
        return !config.isConfiguredForWeightCalculations
    }

    private var loadedUnitCount: Int {
        loadedItems.reduce(0) { $0 + max($1.quantity, 0) }
    }

    private var loadedMassKg: Double {
        loadedItems.reduce(0) { sum, li in
            sum + (li.item?.weightKg ?? 0) * Double(max(li.quantity, 0))
        }
    }

    private var itemsSectionTitle: String {
        "Items (\(loadedUnitCount) loaded, \(Formatters.kg(loadedMassKg)))"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if showCaravanSetupBanner {
                        AppWarningBanner(message: "Configure caravan settings to see weight calculations.")
                    }

                    if libraryItems.isEmpty {
                        LoadEmptyStateView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            Section {
                                ForEach(libraryItems) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.headline)
                                                .foregroundStyle(AppColors.textPrimary)
                                            Text(Formatters.kg(item.weightKg))
                                                .font(.footnote)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                        Spacer(minLength: 8)
                                        Text("×\(quantity(for: item))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppColors.blue)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 8)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                                            .fill(AppColors.inputSurface)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                                                    .strokeBorder(AppColors.inputBorder, lineWidth: 1)
                                            }
                                            .padding(.vertical, 4)
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Load") {
                                            viewModel.load(item: item, loadedItems: loadedItems, in: modelContext)
                                        }
                                        .tint(AppColors.green)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button("Unload") {
                                            viewModel.unload(item: item, loadedItems: loadedItems, in: modelContext)
                                        }
                                        .tint(AppColors.orange)
                                    }
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        viewModel.delete(item: libraryItems[index], loadedItems: loadedItems, in: modelContext)
                                    }
                                }
                            } header: {
                                AppSectionHeading(
                                    itemsSectionTitle,
                                    caption: "Swipe left on a row for Load • Swipe right for Unload"
                                )
                                .textCase(nil)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundSecondary)

                AppFloatingAddButton(accessibilityLabel: "Add item") {
                    showAddItem = true
                }
                .padding(.trailing, AppScreenMetrics.horizontalPadding)
                .padding(.bottom, 12)
            }
            .navigationTitle("Load")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddItem, onDismiss: {
                newName = ""
                newWeight = ""
            }) {
                AddLibraryItemSheet(
                    name: $newName,
                    weightText: $newWeight,
                    onAdd: commitAdd
                )
            }
        }
    }

    private func commitAdd() {
        guard let weight = Double(newWeight.replacingOccurrences(of: ",", with: ".")),
              weight > 0,
              !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        viewModel.addLibraryItem(name: newName, weightKg: weight, in: modelContext)
        newName = ""
        newWeight = ""
        showAddItem = false
    }

    private func quantity(for item: LibraryItem) -> Int {
        loadedItems
            .filter { $0.item?.id == item.id }
            .reduce(0) { $0 + max($1.quantity, 0) }
    }
}

// MARK: - Empty state

private struct LoadEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(AppColors.blue.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("No Items")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Tap + to add items to your load list.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add item sheet

private struct AddLibraryItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var name: String
    @Binding var weightText: String
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppLabeledTextField(
                        "Item Name",
                        placeholder: "e.g., Camping Chair",
                        text: $name
                    )

                    AppLabeledTextField(
                        "Weight (kg)",
                        placeholder: "e.g., 5.5",
                        text: $weightText,
                        keyboard: .decimalPad
                    )

                    AppPrimaryButton("Add Item") {
                        onAdd()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .appScreenBackground()
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
