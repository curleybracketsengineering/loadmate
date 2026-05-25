import SwiftUI
import SwiftData

struct LoadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LibraryItem.name)]) private var libraryItems: [LibraryItem]
    @Query private var allLoadedItems: [LoadedItem]
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = LoadViewModel()
    @State private var showAddItem = false
    @State private var newName = ""
    @State private var newWeight = ""
    @State private var libraryItemEditSession: LibraryItemEditSession?
    @State private var searchText = ""
    @State private var showAddTrip = false
    @State private var newTripName = ""
    @State private var tripPendingRename: Trip?
    @State private var tripRenameField = ""

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: appStates.first)
    }

    private var activeTrip: Trip? {
        TripStore.activeTrip(for: activeProfile)
    }

    private var profileTrips: [Trip] {
        TripStore.sortedTrips(for: activeProfile)
    }

    private var loadedItems: [LoadedItem] {
        TripStore.loadedItems(for: activeTrip, from: allLoadedItems)
    }

    private var filteredLibraryItems: [LibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return libraryItems }
        return libraryItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var showSetupBanner: Bool {
        guard let profile = activeProfile else { return true }
        return !profile.isConfiguredForWeightCalculations
    }

    private var setupBannerMessage: String {
        guard let profile = activeProfile else {
            return "Add a vehicle in Settings to see weight calculations."
        }
        return profile.kind == .motorhome
            ? "Configure motorhome settings (MAM and axle limits) for weight calculations."
            : "Configure caravan settings to see weight calculations."
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
                    if showSetupBanner {
                        AppWarningBanner(message: setupBannerMessage)
                    }

                    if let profile = activeProfile, !profileTrips.isEmpty {
                        TripPickerBar(
                            profile: profile,
                            trips: profileTrips,
                            activeTrip: activeTrip,
                            showAddTrip: $showAddTrip,
                            tripPendingRename: $tripPendingRename,
                            tripRenameField: $tripRenameField
                        )
                    }

                    if libraryItems.isEmpty {
                        LoadEmptyStateView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            AppSearchField(text: $searchText)
                                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                                .padding(.top, AppScreenMetrics.smallSpacing)
                                .padding(.bottom, AppScreenMetrics.controlSpacing)

                            List {
                            Section {
                                if filteredLibraryItems.isEmpty {
                                    Text("No items match your search.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSupporting)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .listRowInsets(EdgeInsets(
                                            top: 6,
                                            leading: AppScreenMetrics.cardInteriorPadding,
                                            bottom: 6,
                                            trailing: AppScreenMetrics.cardInteriorPadding
                                        ))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                } else {
                                ForEach(filteredLibraryItems) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: AppScreenMetrics.controlSpacing) {
                                        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                                            Text(item.name)
                                                .font(.headline)
                                                .foregroundStyle(Color.primary)
                                            Text(Formatters.kg(item.weightKg))
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textSupporting)
                                        }
                                        Spacer(minLength: AppScreenMetrics.smallSpacing)
                                        Text("×\(quantity(for: item))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.accentColor)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, AppScreenMetrics.smallSpacing)
                                    .listRowInsets(EdgeInsets(
                                        top: 6,
                                        leading: AppScreenMetrics.cardInteriorPadding,
                                        bottom: 6,
                                        trailing: AppScreenMetrics.cardInteriorPadding
                                    ))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                            .padding(.vertical, 4)
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Load") {
                                            viewModel.load(
                                                item: item,
                                                trip: activeTrip,
                                                loadedItems: loadedItems,
                                                in: modelContext
                                            )
                                        }
                                        .tint(AppColors.green)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button("Unload") {
                                            viewModel.unload(item: item, loadedItems: loadedItems, in: modelContext)
                                        }
                                        .tint(AppColors.orange)
                                    }
                                    .contextMenu {
                                        Button {
                                            libraryItemEditSession = LibraryItemEditSession(item: item)
                                        } label: {
                                            Label("Edit Item", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            viewModel.delete(item: item, allLoadedItems: allLoadedItems, in: modelContext)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                }
                            } header: {
                                AppSectionHeading(
                                    itemsSectionTitle,
                                    caption: "Swipe left for Load • Swipe right for Unload • Long-press a row to edit or delete"
                                )
                                .textCase(nil)
                            }
                            .headerProminence(.increased)
                            }
                            .listStyle(.insetGrouped)
                            .scrollContentBackground(.hidden)
                            .scrollDismissesKeyboard(.interactively)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))

                AppFloatingAddButton(accessibilityLabel: "Add item") {
                    showAddItem = true
                }
                .padding(.trailing, AppScreenMetrics.horizontalPadding)
                .padding(.bottom, AppScreenMetrics.fieldSpacing)
            }
            .appPrincipalTabTitle("Load")
            .task(id: profiles.map(\.id)) {
                TripStore.ensureTripsMigrated(in: modelContext, profiles: profiles)
            }
            .sheet(isPresented: $showAddTrip, onDismiss: {
                newTripName = ""
            }) {
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
                Button("Cancel", role: .cancel) {
                    tripPendingRename = nil
                }
            }
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
            .sheet(item: $libraryItemEditSession, onDismiss: {
                libraryItemEditSession = nil
            }) { session in
                EditLibraryItemSheet(
                    initialName: session.name,
                    initialWeightText: session.weightText,
                    onSave: { name, weightKg in
                        if let item = libraryItems.first(where: { $0.id == session.id }) {
                            viewModel.updateLibraryItem(item, name: name, weightKg: weightKg, in: modelContext)
                        }
                        libraryItemEditSession = nil
                    },
                    onCancel: {
                        libraryItemEditSession = nil
                    }
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
        VStack(spacing: AppScreenMetrics.fieldSpacing) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.45))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("No Items")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primary)

            Text("Tap + to add items to your load list.")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppScreenMetrics.sectionSpacingLoose)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Edit item session (sheet identity)

private struct LibraryItemEditSession: Identifiable, Hashable {
    let id: UUID
    let name: String
    let weightText: String

    init(item: LibraryItem) {
        id = item.id
        name = item.name
        weightText = Formatters.oneDecimal.string(from: NSNumber(value: item.weightKg)) ?? "\(item.weightKg)"
    }
}

// MARK: - Edit item sheet

private struct EditLibraryItemSheet: View {
    let initialName: String
    let initialWeightText: String
    let onSave: (String, Double) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var weightText = ""

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

                    AppPrimaryButton("Save Changes") {
                        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
                              weight > 0,
                              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }
                        onSave(name, weight)
                    }
                    .padding(.top, AppScreenMetrics.tinySpacing)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .appScreenBackground()
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear {
                name = initialName
                weightText = initialWeightText
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
                    .padding(.top, AppScreenMetrics.tinySpacing)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
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
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
