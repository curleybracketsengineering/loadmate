import SwiftUI
import SwiftData

struct LoadView: View {
    @Environment(\.usePadLayout) private var usePadLayout

    var body: some View {
        if usePadLayout {
            LoadPlacementPadView()
        } else {
            LoadPhoneTabView()
        }
    }
}

struct LoadTabContent: View {
    @Binding var showAddItem: Bool

    init(showAddItem: Binding<Bool> = .constant(false)) {
        _showAddItem = showAddItem
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LibraryItem.name)]) private var libraryItems: [LibraryItem]
    @Query private var allLoadedItems: [LoadedItem]
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = LoadViewModel()
    @State private var newName = ""
    @State private var newWeight = ""
    @State private var libraryItemEditSession: LibraryItemEditSession?
    @State private var searchText = ""
    @State private var showAddTrip = false
    @State private var newTripName = ""
    @State private var tripPendingRename: Trip?
    @State private var tripRenameField = ""
    @State private var showStarterKitConfirm = false
    @State private var tripPendingNotes: Trip?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
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
        return profile.weightCalculationSetupSummaryMessage
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

    private var showsStarterKit: Bool {
        guard let profile = activeProfile else { return false }
        guard profile.kind == .caravan || profile.kind == .motorhome else { return false }
        return !profile.hasAppliedStarterKit
    }

    private var starterKitVehicleLabel: String {
        activeProfile?.kind == .motorhome ? "motorhome" : "caravan"
    }

    private var starterKitAlertMessage: String {
        "Adds typical \(starterKitVehicleLabel) items to your library and loads any that are not on this trip yet. "
            + "Your existing items and weights are kept."
    }

    var body: some View {
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
                            tripRenameField: $tripRenameField,
                            onOpenTripNotes: { tripPendingNotes = $0 }
                        )
                    }

                    if let profile = activeProfile,
                       profile.kind == .motorhome,
                       profile.usesManualTowBarLoad,
                       let trip = activeTrip {
                        towBarEntryCard(for: trip)
                            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                            .padding(.bottom, AppScreenMetrics.controlSpacing)
                    }

                    if libraryItems.isEmpty {
                        LoadEmptyStateView(
                            vehicleKind: activeProfile?.kind,
                            showsStarterKit: showsStarterKit,
                            onLoadStarterKit: requestStarterKit,
                            onAddItem: { showAddItem = true }
                        )
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
                                HStack(alignment: .firstTextBaseline, spacing: AppScreenMetrics.smallSpacing) {
                                    AppSectionHeading(itemsSectionTitle)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if showsStarterKit {
                                        Button(action: requestStarterKit) {
                                            Image(systemName: "shippingbox")
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(Color.accentColor)
                                                .frame(minWidth: 44, minHeight: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Add starter kit")
                                        .pointerHelp("Starter kit")
                                    }

                                    Button {
                                        showAddItem = true
                                    } label: {
                                        Image(systemName: "plus.circle")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(Color.accentColor)
                                            .frame(minWidth: 44, minHeight: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add item")
                                    .pointerHelp("Add item")
                                }
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
            .alert("Add starter kit?", isPresented: $showStarterKitConfirm) {
                Button("Add items") {
                    applyStarterKit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(starterKitAlertMessage)
            }
            .sheet(item: $tripPendingNotes) { trip in
                if let profile = activeProfile {
                    TripLoadingNotesSheet(profile: profile, trip: trip)
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

    private func requestStarterKit() {
        guard showsStarterKit else { return }
        if libraryItems.isEmpty {
            applyStarterKit()
        } else {
            showStarterKitConfirm = true
        }
    }

    private func applyStarterKit() {
        guard let profile = activeProfile else { return }
        switch profile.kind {
        case .caravan:
            _ = viewModel.applyCaravanStarterKit(
                trip: activeTrip,
                libraryItems: libraryItems,
                loadedItems: loadedItems,
                in: modelContext
            )
        case .motorhome:
            _ = viewModel.applyMotorhomeStarterKit(
                trip: activeTrip,
                libraryItems: libraryItems,
                loadedItems: loadedItems,
                in: modelContext
            )
        default:
            return
        }
        profile.hasAppliedStarterKit = true
        _ = SyncDebugSaveHelper.save(modelContext, source: "LoadView.applyStarterKit")
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

    @ViewBuilder
    private func towBarEntryCard(for trip: Trip) -> some View {
        AppGroupedCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tow bar")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: AppScreenMetrics.smallSpacing)
                    Text("Trip value")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSupporting)
                }

                AppBoundedNumberField(
                    value: Binding(
                        get: { trip.manualTowBarLoadKg },
                        set: { newValue in
                            trip.manualTowBarLoadKg = max(0, newValue)
                            saveTowBarValue()
                        }
                    ),
                    fractionDigitsUpperBound: 0
                )

                Text("Enter the measured tow bar downforce for this trip. The app adds this to rear axle and gross weight estimates, and checks your tow bar limit.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func saveTowBarValue() {
        _ = SyncDebugSaveHelper.save(modelContext, source: "LoadView.saveTowBarValue")
    }
}

private struct LoadPhoneTabView: View {
    @Query(sort: [SortDescriptor(\LibraryItem.name)]) private var libraryItems: [LibraryItem]
    @State private var showAddItem = false

    var body: some View {
        NavigationStack {
            LoadTabContent(showAddItem: $showAddItem)
                .appPrincipalTabTitle("Load")
                .toolbar {
                    if libraryItems.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAddItem = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .accessibilityLabel("Add item")
                            .pointerHelp("Add item")
                        }
                    }
                }
        }
    }
}

// MARK: - Empty state

private struct LoadEmptyStateView: View {
    var vehicleKind: VehicleKind?
    var showsStarterKit: Bool
    var onLoadStarterKit: () -> Void
    var onAddItem: () -> Void

    private var vehicleLabel: String {
        vehicleKind == .motorhome ? "motorhome" : "caravan"
    }

    var body: some View {
        VStack(spacing: AppScreenMetrics.sectionSpacing) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.45))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: AppScreenMetrics.controlSpacing) {
                Text("No Items")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(
                    showsStarterKit
                        ? "Add items you take on tour, or start from a typical \(vehicleLabel) list."
                        : "Add items you take on tour."
                )
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppScreenMetrics.sectionSpacing)
            }

            VStack(spacing: AppScreenMetrics.controlSpacing) {
                if showsStarterKit {
                    Button(action: onLoadStarterKit) {
                        Text("Load starter kit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Adds typical \(vehicleLabel) items with estimated weights")

                    Button(action: onAddItem) {
                        Text("Add your own item")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: onAddItem) {
                        Text("Add your own item")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, AppScreenMetrics.sectionSpacing)
            .frame(maxWidth: 360)
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
    @Environment(\.usePadLayout) private var usePadLayout

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
                        keyboard: AppKeyboard.numeric(usePadLayout: usePadLayout)
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
        .presentationDetents([.height(AppScreenMetrics.compactTwoFieldSheetHeight), .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}

// MARK: - Add item sheet

private struct AddLibraryItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.usePadLayout) private var usePadLayout

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
                        keyboard: AppKeyboard.numeric(usePadLayout: usePadLayout)
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
        .presentationDetents([.height(AppScreenMetrics.compactTwoFieldSheetHeight), .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}
