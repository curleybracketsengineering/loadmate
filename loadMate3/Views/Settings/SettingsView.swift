import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    var onNavigateToSummary: (() -> Void)?

    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.padTopTabBarActive) private var padTopTabBarActive
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.vehicleLookup) private var vehicleLookup
    @AppStorage(TyreSupport.pressureUnitAppStorageKey) private var pressureUnitRaw = PressureUnit.psi.rawValue
    @Query(sort: [SortDescriptor(\VehicleProfile.sortOrder)]) private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var cloudSync: CloudSyncMonitor
    @State private var appState: AppState?
    @State private var editingProfile: VehicleProfile?
    @State private var isWeightFactorsExpanded = false
    @State private var showAddVehicle = false
    @State private var newVehicleName = ""
    @State private var newVehicleKind: VehicleKind = .caravan
    @State private var profilePendingRename: VehicleProfile?
    @State private var profileRenameField = ""
    @State private var showNoseSafeZoneHelp = false
    @State private var showSetupIncompleteAlert = false
    @State private var setupIncompleteAlertMessage = ""
    @State private var showSyncDebugPanel = false
    @State private var showPlateSourcePicker = false
    @State private var showPlateCamera = false
    @State private var showPlateLibraryPicker = false
    @State private var selectedPlateLibraryItem: PhotosPickerItem?
    @State private var isAnalyzingPlate = false
    @State private var plateReviewItem: VehiclePlateReviewItem?
    @State private var platePreviewImage: UIImage?
    @State private var plateAnalysisError: String?
    @State private var showVINChipSourcePicker = false
    @State private var showVINChipCamera = false
    @State private var showVINChipLibraryPicker = false
    @State private var selectedVINChipLibraryItem: PhotosPickerItem?
    @State private var isAnalyzingVINChip = false
    @State private var vinChipReviewItem: CRiSVINChipReviewItem?
    @State private var vinChipAnalysisError: String?
    @State private var isLookingUpVehicle = false
    @State private var vehicleLookupError: String?
    @State private var vehicleLookupReviewItem: VehicleLookupReviewItem?

    private var sortedProfiles: [VehicleProfile] {
        VehicleProfileStore.uniqueSortedProfiles(profiles)
    }

    /// Changes when profiles are added, removed, renamed, or merged — not only when the count changes.
    private var profileListToken: String {
        sortedProfiles.map { "\($0.id.uuidString):\($0.name):\($0.kindRaw)" }.joined(separator: "|")
    }

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: appState)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = editingProfile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                            AppHeroSection(
                                systemImage: "gearshape",
                                title: "Settings",
                                subtitle: profileSubtitle(profile)
                            )

                            vehicleProfilesSection(editing: profile)

                            if profile.kind == .caravan {
                                caravanSettings(profile)
                            } else {
                                motorhomeSettings(profile)
                            }

                            warrantySettings(profile)

                            insuranceSettings(profile)

                            tyreSafetySettings()

                            aboutSection()

                            iCloudSyncSection()

                            Text("This app is an estimator only. Always physically measure weight and axle loads on a weighbridge.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .padding(.top, AppScreenMetrics.tinySpacing)

                            VStack(spacing: AppScreenMetrics.controlSpacing) {
                                AppPrimaryButton("Save Configuration", systemImage: "checkmark.circle.fill") {
                                    guard viewModel.save(modelContext) else { return }
                                    if let profile = editingProfile {
                                        WarrantyStore.syncInsuranceRenewalEvents(for: profile, in: modelContext)
                                    }
                                    if let profile = editingProfile, profile.isConfiguredForWeightCalculations {
                                        onNavigateToSummary?()
                                    } else if let profile = editingProfile {
                                        setupIncompleteAlertMessage = profile.weightCalculationSetupSummaryMessage
                                        showSetupIncompleteAlert = true
                                    }
                                }
                            }
                            .padding(.top, AppScreenMetrics.smallSpacing)
                        }
                        .padding(.horizontal, usePadLayout ? 0 : AppScreenMetrics.horizontalPadding)
                        .padding(.top, AppScreenMetrics.verticalScreenPadding)
                        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                        .padReadableContent(maxWidth: PadContentLayout.settingsMaxWidth)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .appScreenBackground()
            .modifier(SettingsNavigationTitleModifier())
        }
        .task(id: profileListToken) {
            let resolvedState = AppStateStore.resolve(in: modelContext, existing: appStates)
            _ = VehicleProfileSyncReconciliation.reconcile(in: modelContext, appState: resolvedState)

            let storedProfiles = (try? modelContext.fetch(FetchDescriptor<VehicleProfile>())) ?? profiles
            let boot = viewModel.bootstrap(
                in: modelContext,
                profiles: VehicleProfileStore.uniqueSortedProfiles(storedProfiles),
                appState: resolvedState
            )
            appState = boot.appState

            if let editing = editingProfile,
               let match = boot.profiles.first(where: { $0.id == editing.id }) {
                editingProfile = match
            } else {
                editingProfile = VehicleProfileStore.activeProfile(profiles: boot.profiles, appState: boot.appState)
            }
        }
        .task {
            await cloudSync.refresh()
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleSheet(
                name: $newVehicleName,
                kind: $newVehicleKind,
                onAdd: {
                    guard let state = appState else { return }
                    let created = viewModel.addProfile(
                        name: newVehicleName,
                        kind: newVehicleKind,
                        profiles: profiles,
                        appState: state,
                        in: modelContext
                    )
                    editingProfile = created
                    newVehicleName = ""
                    newVehicleKind = .caravan
                    showAddVehicle = false
                },
                onCancel: {
                    newVehicleName = ""
                    showAddVehicle = false
                }
            )
        }
        .sheet(isPresented: $showSyncDebugPanel) {
            SyncDebugPanelView(
                cloudSync: cloudSync,
                appState: appState,
                activeProfileName: activeProfile?.name
            )
        }
        .alert("5–7% safe zone", isPresented: $showNoseSafeZoneHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(Self.noseSafeZoneHelpMessage)
        }
        .alert("Setup incomplete", isPresented: $showSetupIncompleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(setupIncompleteAlertMessage)
        }
        .alert("Rename vehicle", isPresented: Binding(
            get: { profilePendingRename != nil },
            set: { if !$0 { profilePendingRename = nil } }
        )) {
            TextField("Vehicle name", text: $profileRenameField)
            Button("Save") {
                if let profile = profilePendingRename {
                    let trimmed = profileRenameField.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.name = trimmed.isEmpty ? profile.kind.displayName : trimmed
                    viewModel.save(modelContext)
                }
                profilePendingRename = nil
            }
            Button("Cancel", role: .cancel) {
                profilePendingRename = nil
            }
        }
        .confirmationDialog("Scan vehicle plate", isPresented: $showPlateSourcePicker, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showPlateCamera = true }
            }
            Button("Choose from library") { showPlateLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(plateScanPickerMessage(for: editingProfile?.kind ?? .caravan))
        }
        .photosPicker(isPresented: $showPlateLibraryPicker, selection: $selectedPlateLibraryItem, matching: .images)
        .onChange(of: selectedPlateLibraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedPlateLibraryItem = nil
                        analyzePlateImage(image)
                    }
                } else {
                    await MainActor.run {
                        selectedPlateLibraryItem = nil
                        plateAnalysisError = "Could not load that photo. Try another image of the plate."
                    }
                }
            }
        }
        .sheet(isPresented: $showPlateCamera) {
            MaintenanceImagePicker(sourceType: .camera) { image in
                analyzePlateImage(image)
            }
        }
        .sheet(item: $plateReviewItem) { item in
            if let profile = editingProfile {
                VehiclePlateReviewSheet(kind: profile.kind, item: item) { selected in
                    applyPlateSuggestions(selected, image: item.image, to: profile)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { platePreviewImage != nil },
            set: { if !$0 { platePreviewImage = nil } }
        )) {
            if let image = platePreviewImage {
                ManufacturerPlatePhotoViewer(image: image)
            }
        }
        .confirmationDialog("Scan CRiS VIN Chip", isPresented: $showVINChipSourcePicker, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showVINChipCamera = true }
            }
            Button("Choose from library") { showVINChipLibraryPicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Photograph the VIN Chip sticker or QR code (window or gas locker) so the VIN can be suggested.")
        }
        .photosPicker(isPresented: $showVINChipLibraryPicker, selection: $selectedVINChipLibraryItem, matching: .images)
        .onChange(of: selectedVINChipLibraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedVINChipLibraryItem = nil
                        analyzeVINChipImage(image)
                    }
                } else {
                    await MainActor.run {
                        selectedVINChipLibraryItem = nil
                        vinChipAnalysisError = "Could not load that photo. Try another image of the VIN Chip sticker or QR code."
                    }
                }
            }
        }
        .sheet(isPresented: $showVINChipCamera) {
            MaintenanceImagePicker(sourceType: .camera) { image in
                analyzeVINChipImage(image)
            }
        }
        .sheet(item: $vinChipReviewItem) { item in
            if let profile = editingProfile {
                CRiSVINChipReviewSheet(item: item) { vin, savePhoto, image in
                    applyVINChipResult(vin: vin, savePhoto: savePhoto, image: image, to: profile)
                }
            }
        }
        .sheet(item: $vehicleLookupReviewItem) { item in
            if let profile = editingProfile {
                VehicleLookupReviewSheet(result: item.result) { applyMake, applyModel in
                    applyVehicleLookup(item.result, applyMake: applyMake, applyModel: applyModel, to: profile)
                }
            }
        }
    }

    @ViewBuilder
    private func warrantySettings(_ profile: VehicleProfile) -> some View {
        AppSettingsSection(
            "Service & warranty",
            caption: "Turn off only if you do not want a service timeline for this vehicle. Cover is optional — services still need logging."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Toggle(isOn: boolBinding(for: \.warrantyAvailable, on: profile)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show service & warranty")
                            .font(.subheadline.weight(.medium))
                        Text(profile.warrantyAvailable
                            ? "Shows the service timeline in Care, with optional manufacturer cover."
                            : "Hides the service & warranty area for this vehicle.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                }
                .tint(Color.accentColor)

                if profile.warrantyAvailable {
                    Toggle(isOn: ukMarketBinding(for: profile)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UK / Northern Ireland market")
                                .font(.subheadline.weight(.medium))
                            Text(profile.warrantyUKMarket
                                ? "Offers UK manufacturer warranty starters (Swift, Bailey, Coachman, Elddis, Adria)."
                                : "Manufacturer starters are hidden. Build a custom plan from your local handbook.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                    }
                    .tint(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func insuranceSettings(_ profile: VehicleProfile) -> some View {
        AppSettingsSection(
            "Insurance",
            caption: "Optional. Set a date to add a yearly insurance check. Insurer details are used if you record an accident."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                TextField("Insurer name", text: Binding(
                    get: { profile.insuranceProviderName },
                    set: {
                        profile.insuranceProviderName = $0
                        viewModel.save(modelContext)
                    }
                ))
                TextField("Policy number", text: Binding(
                    get: { profile.insurancePolicyNumber },
                    set: {
                        profile.insurancePolicyNumber = $0
                        viewModel.save(modelContext)
                    }
                ))
                TextField("Claims phone", text: Binding(
                    get: { profile.insuranceClaimsPhone },
                    set: {
                        profile.insuranceClaimsPhone = $0
                        viewModel.save(modelContext)
                    }
                ))
                .keyboardType(.phonePad)
                Text("If you travel in Europe, keep a paper European Accident Statement, hi-vis jackets, and check whether your cover abroad is comprehensive or third-party only.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)

                if profile.insuranceStartDate != nil {
                    DatePicker(
                        "Insurance",
                        selection: insuranceStartDateBinding(on: profile),
                        displayedComponents: .date
                    )
                    Button("Clear date") {
                        profile.insuranceStartDate = nil
                        viewModel.save(modelContext)
                        WarrantyStore.syncInsuranceRenewalEvents(for: profile, in: modelContext)
                    }
                    .font(.subheadline)
                } else {
                    Button {
                        profile.insuranceStartDate = Calendar.current.startOfDay(for: Date())
                        viewModel.save(modelContext)
                        WarrantyStore.syncInsuranceRenewalEvents(for: profile, in: modelContext)
                    } label: {
                        HStack {
                            Text("Insurance")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("Not set")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set insurance date")
                }
            }
        }
    }

    @ViewBuilder
    private func tyreSafetySettings() -> some View {
        AppSettingsSection(
            "Tyre Safety",
            caption: "App-wide preferences for tyre pressure display."
        ) {
            Picker("Pressure unit", selection: $pressureUnitRaw) {
                ForEach(PressureUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func profileSubtitle(_ profile: VehicleProfile) -> String {
        let manufacturer = profile.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = profile.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = [manufacturer, modelName].filter { !$0.isEmpty }.joined(separator: " ")
        if identity.isEmpty {
            return "\(profile.kind.displayName) — \(profile.name)"
        }
        return "\(profile.kind.displayName) — \(profile.name)\n\(identity)"
    }

    private static let developerEmail = "smatheson6@icloude.com"

    @ViewBuilder
    private func iCloudSyncSection() -> some View {
        AppSettingsSection(
            "iCloud sync",
            caption: "Keep your data consistent across your own iPhone and iPad."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                    Image(systemName: cloudSync.accountStatus.systemImage)
                        .font(.title3)
                        .foregroundStyle(cloudSync.accountStatus == .available ? Color.accentColor : Color.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text(cloudSync.accountStatus.settingsTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(cloudSync.accountStatus.settingsDetail)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if cloudSync.accountStatus != .available {
                    AppSecondaryButton("Open Settings") {
                        openSystemSettings()
                    }

                    AppSecondaryButton("Check Again") {
                        Task {
                            await cloudSync.refresh()
                        }
                    }
                }
            }
        }
        .onTapGesture(count: 7) {
            SyncDebugLogger.shared.record(
                category: "panel",
                message: "Hidden sync debug panel unlocked from Settings."
            )
            showSyncDebugPanel = true
        }
    }

    @ViewBuilder
    private func aboutSection() -> some View {
        AppSettingsSection(
            "About",
            caption: "Who built Lyneqo Caravan & Motorhome and why it exists."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text(
                    """
                    Lyneqo Caravan & Motorhome was built to give owners one clear place to look after their vehicle. After four decades in software development, I wanted to put that experience into a free utility that covers the full life of your rig: from safe loading and trip readiness through to maintenance, tyres, documents and warranty.

                    If you have ideas for how to improve it, I'd love to hear from you.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

                if let mailURL = URL(string: "mailto:\(Self.developerEmail)") {
                    Link(destination: mailURL) {
                        Label(Self.developerEmail, systemImage: "envelope")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
    }

    // MARK: - Profiles

    @ViewBuilder
    private func vehicleProfilesSection(editing: VehicleProfile) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                AppSectionHeading(
                    "My vehicles",
                    caption: "Switch between caravan and motorhome. Each has its own limits; use trips on Load for separate packing lists."
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button {
                        showAddVehicle = true
                    } label: {
                        Label("Add vehicle", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Vehicle list actions")
                .pointerHelp("Options")
            }

            AppGroupedCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedProfiles) { profile in
                        if profile.id != sortedProfiles.first?.id {
                            Divider()
                        }
                        vehicleProfileRow(profile, editing: editing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func vehicleProfileRow(_ profile: VehicleProfile, editing: VehicleProfile) -> some View {
        let isSelected = activeProfile?.id == profile.id
        HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
            Button {
                guard let state = appState else { return }
                viewModel.setActiveProfile(profile, appState: state, in: modelContext)
                editingProfile = profile
            } label: {
                HStack(spacing: AppScreenMetrics.controlSpacing) {
                    Image(systemName: profile.kind.systemImage)
                        .font(.body)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.primary)
                        Text(profile.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Selected")
                    }
                }
                .padding(.vertical, AppScreenMetrics.tinySpacing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double tap to select. Press and hold or tap … for rename or remove.")

            Menu {
                profileManagementActions(profile)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(profile.name)")
            .pointerHelp("Options")
        }
        .contextMenu {
            profileManagementActions(profile)
        }
    }

    @ViewBuilder
    private func profileManagementActions(_ profile: VehicleProfile) -> some View {
        Button {
            profilePendingRename = profile
            profileRenameField = profile.name
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        if sortedProfiles.count > 1 {
            Button(role: .destructive) {
                guard let state = appState else { return }
                viewModel.deleteProfile(profile, profiles: profiles, appState: state, in: modelContext)
                editingProfile = VehicleProfileStore.activeProfile(profiles: profiles, appState: state)
            } label: {
                Label("Remove vehicle", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func caravanPlateFields(_ profile: VehicleProfile) -> some View {
        if usePadLayout {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppAlignedLabeledNumberFieldRow(
                    left: AppLabeledNumberField(
                        "MTPLM (kg)",
                        caption: "Maximum Technically Permissible Laden Mass",
                        value: binding(for: \.mtplmKg, on: profile),
                        fractionDigitsUpperBound: 0
                    ),
                    right: AppLabeledNumberField(
                        "MIRO (kg)",
                        caption: "Mass in Running Order — used when no weighbridge weight is entered",
                        value: binding(for: \.baseWeightKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                )
                AppAlignedLabeledNumberFieldRow(
                    left: AppLabeledNumberField(
                        "Weighbridge weight (kg)",
                        caption: "Actual caravan weight before trip items — used instead of MIRO when entered",
                        value: binding(for: \.weighbridgeWeightKg, on: profile),
                        fractionDigitsUpperBound: 0
                    ),
                    right: AppLabeledNumberField(
                        "Caravan hitch limit (kg)",
                        caption: "Maximum nose weight on the caravan hitch",
                        value: binding(for: \.caravanMaxNoseKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                )
            }
        } else {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppLabeledNumberField(
                    "MTPLM (kg)",
                    caption: "Maximum Technically Permissible Laden Mass",
                    value: binding(for: \.mtplmKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "MIRO (kg)",
                    caption: "Mass in Running Order — used when no weighbridge weight is entered",
                    value: binding(for: \.baseWeightKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "Weighbridge weight (kg)",
                    caption: "Actual caravan weight before trip items — used instead of MIRO when entered",
                    value: binding(for: \.weighbridgeWeightKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "Caravan hitch limit (kg)",
                    caption: "Maximum nose weight on the caravan hitch",
                    value: binding(for: \.caravanMaxNoseKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
            }
        }
    }

    // MARK: - Caravan

    @ViewBuilder
    private func caravanSettings(_ profile: VehicleProfile) -> some View {
        AppSettingsSection("Caravan", caption: "Weights from your caravan plate or handbook.") {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                plateScanControls(for: profile)
                AppLabeledTextField(
                    "Manufacturer",
                    caption: "Brand from the manufacturer plate when shown",
                    placeholder: "e.g. Swift",
                    text: stringBinding(for: \.manufacturer, on: profile)
                )
                AppLabeledTextField(
                    "Model",
                    caption: "Model or range from the plate when shown",
                    placeholder: "e.g. Conqueror 645",
                    text: stringBinding(for: \.modelName, on: profile)
                )
                AppLabeledTextField(
                    "VIN / chassis",
                    caption: "From the manufacturer plate, CRiS documents or VIN Chip sticker",
                    placeholder: "e.g. SGA…",
                    text: stringBinding(for: \.vinChassisNumber, on: profile)
                )
                vinChipScanControls(for: profile)
                caravanPlateFields(profile)
                Toggle(isOn: boolBinding(for: \.hasBikeRack, on: profile)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bike rack fitted")
                            .font(.subheadline.weight(.medium))
                        Text(profile.hasBikeRack
                            ? "Shows the bike rack on the placement map and offers the bike rack location when assigning items."
                            : "Shows your caravan without a rear rack. The bike rack location is hidden.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                }
                .tint(Color.accentColor)
            }
        }

        AppSettingsSection("Vehicle", caption: "Your car’s towing specification.") {
            let baselineSummary = WeightCalculator.summary(profile: profile, loadedItems: [])
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppLabeledNumberField(
                    "Car tow ball limit (kg)",
                    caption: "Maximum tow ball weight your car can handle",
                    value: binding(for: \.carMaxTowBallKg, on: profile),
                    fractionDigitsUpperBound: 0
                )

                if SettingsView.hasCaravanContextForFivePercentRule(profile),
                   baselineSummary.towBallMinKg > 0 {
                    let effectiveCap = profile.effectiveMaxTowBallKg
                    if effectiveCap > 0, baselineSummary.isTowVehicleUnsuitable {
                        AppWarningBanner(
                            message: SettingsView.carTowBallFivePercentConflictMessage(
                                profile: profile,
                                summary: baselineSummary
                            )
                        )
                    } else if !(effectiveCap > 0 && baselineSummary.isTowVehicleUnsuitable) {
                        Text(SettingsView.carTowBallFivePercentHintText(profile: profile, summary: baselineSummary))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        noseSafeZoneBasisSection(profile)

        caravanWeightFactors(profile)
    }

    private static let noseSafeZoneHelpMessage = """
        Choose what weight to use for the recommended 5%–7% nose weight band on the Summary tab.

        MTPLM uses your caravan plate maximum laden mass. The band stays fixed (for example 75–105 kg when MTPLM is 1,500 kg), even if you travel lighter. This matches many manufacturer guides.

        Laden weight uses your actual caravan mass (weighbridge plus trip items). The band updates as you load or unload, which aligns with NCC guidance when you know your real weight.

        Your car tow ball limit and caravan hitch limit still apply—the lowest of those caps and the 5–7% band is always used.
        """

    @ViewBuilder
    private func noseSafeZoneBasisSection(_ profile: VehicleProfile) -> some View {
        AppSettingsSection(
            "Nose weight safe zone",
            caption: "How the 5%–7% recommended band is calculated on the Summary tab."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                HStack(alignment: .center, spacing: AppScreenMetrics.smallSpacing) {
                    Picker("5–7% based on", selection: noseSafeZoneBasisBinding(on: profile)) {
                        ForEach(NoseSafeZoneBasis.allCases) { basis in
                            Text(basis.displayName).tag(basis)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Button {
                        showNoseSafeZoneHelp = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Safe zone help")
                }

                Text(profile.noseSafeZoneBasis == .mtplm
                    ? "Min and max use MTPLM from your plate."
                    : "Min and max use weighbridge weight plus trip items.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func caravanWeightFactors(_ profile: VehicleProfile) -> some View {
        AppCollapsibleSettingsSection(
            "Weight factors",
            caption: "How each location affects estimated nose weight.",
            isExpanded: $isWeightFactorsExpanded
        ) {
            Text("Baseline nose weight uses the percentage below. Calibrate after a weighbridge visit if you can.")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)

            AppFactorField(
                accentTitle: "Base nose weight (%)",
                caption: "Percentage of total caravan weight for the baseline nose estimate",
                value: binding(for: \.noseWeightBasePercent, on: profile)
            )
            AppFactorField(accentTitle: "Front Boot (Locker)", caption: "Very front of the caravan", value: binding(for: \.factorFrontLocker, on: profile))
            AppFactorField(accentTitle: "Front", caption: "Forward seating and storage", value: binding(for: \.factorFront, on: profile))
            AppFactorField(accentTitle: "Middle", caption: "Over or near the axle", value: binding(for: \.factorMiddle, on: profile))
            AppFactorField(accentTitle: "Back", caption: "Rear cupboards and under bed", value: binding(for: \.factorRear, on: profile))
            if profile.hasBikeRack {
                AppFactorField(accentTitle: "Bike Rack", caption: "Bumper or rack behind axle", value: binding(for: \.factorBikeRack, on: profile))
            }

            AppSecondaryButton("Reset weight factors to defaults") {
                viewModel.resetCaravanFactors(profile: profile, in: modelContext)
            }
        }
    }

    // MARK: - Motorhome

    @ViewBuilder
    private func motorhomeSettings(_ profile: VehicleProfile) -> some View {
        AppSettingsSection("Motorhome", caption: "Limits from your vehicle plate (MAM, GTW and axle weights).") {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                plateScanControls(for: profile)
                AppLabeledTextField(
                    "Registration",
                    caption: "UK number plate for this motorhome",
                    placeholder: "e.g. AB12 CDE",
                    text: stringBinding(for: \.registrationMark, on: profile),
                    keyboard: .asciiCapable
                )
                vehicleLookupControls(for: profile)
                AppLabeledTextField(
                    "Manufacturer",
                    caption: "Brand from the manufacturer plate when shown",
                    placeholder: "e.g. Bailey",
                    text: stringBinding(for: \.manufacturer, on: profile)
                )
                AppLabeledTextField(
                    "Model",
                    caption: "Model or range from the plate when shown",
                    placeholder: "e.g. Autograph 79-4F",
                    text: stringBinding(for: \.modelName, on: profile)
                )
                AppLabeledTextField(
                    "VIN / chassis",
                    caption: "From the manufacturer plate, V5C or VIN Chip sticker",
                    placeholder: "e.g. WX1…",
                    text: stringBinding(for: \.vinChassisNumber, on: profile)
                )
                AppLabeledTextField(
                    "Body / cell number",
                    caption: "Converter serial on some EU plates (e.g. Rapido N° de cellule)",
                    placeholder: "e.g. 16-0792-1592616",
                    text: stringBinding(for: \.bodyCellNumber, on: profile)
                )
                vinChipScanControls(for: profile)
                if usePadLayout {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                        AppAlignedLabeledNumberFieldRow(
                            left: AppLabeledNumberField(
                                "MAM (kg)",
                                caption: "Maximum Authorised Mass (gross laden limit)",
                                value: binding(for: \.mtplmKg, on: profile),
                                fractionDigitsUpperBound: 0
                            ),
                            right: AppLabeledNumberField(
                                "GTW (kg)",
                                caption: "Gross train weight — plated vehicle + trailer maximum, not tow-bar nose load",
                                value: binding(for: \.gtwKg, on: profile),
                                fractionDigitsUpperBound: 0
                            )
                        )
                        AppLabeledNumberField(
                            "MRO (kg)",
                            caption: "Mass in Running Order — used when no weighbridge reading is entered",
                            value: binding(for: \.baseWeightKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
                        AppLabeledNumberField(
                            "Weighbridge gross (kg)",
                            caption: "Total laden mass before trip items (optional if axle weights entered)",
                            value: binding(for: \.weighbridgeWeightKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                        AppLabeledNumberField(
                            "MAM (kg)",
                            caption: "Maximum Authorised Mass (gross laden limit)",
                            value: binding(for: \.mtplmKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
                        AppLabeledNumberField(
                            "GTW (kg)",
                            caption: "Gross train weight — plated vehicle + trailer maximum, not tow-bar nose load",
                            value: binding(for: \.gtwKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
                        AppLabeledNumberField(
                            "MRO (kg)",
                            caption: "Mass in Running Order — used when no weighbridge reading is entered",
                            value: binding(for: \.baseWeightKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
                        AppLabeledNumberField(
                            "Weighbridge gross (kg)",
                            caption: "Total laden mass before trip items (optional if axle weights entered)",
                            value: binding(for: \.weighbridgeWeightKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
                    }
                }
            }
        }

        AppSettingsSection(
            "Axle weighbridge",
            caption: "For best accuracy, enter front and rear axle weights from your weighbridge ticket. Front plus rear should match weighbridge gross on the same ticket."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                motorhomeAxleWeighbridgeFields(profile)
                if profile.isMissingMotorhomePlatedAxleLimits {
                    AppWarningBanner(message: VehicleProfile.motorhomePlatedAxleLimitsRequiredMessage)
                }
                MotorhomeWeighbridgeValidationMessages(profile: profile)
            }
        }

        AppSettingsSection(
            "Rear garage",
            caption: "Optional limit for the overhang garage box (often fitted after build). Leave at 0 if not applicable."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppLabeledNumberField(
                    "Max garage load (kg)",
                    caption: "Manufacturer limit for rear storage — see switch below for which locations count",
                    value: binding(for: \.maxGarageKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                Toggle(isOn: boolBinding(for: \.hasBikeRack, on: profile)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bike rack fitted")
                            .font(.subheadline.weight(.medium))
                        Text(profile.hasBikeRack
                            ? "Shows the bike rack on the placement map and offers the bike rack location when assigning items."
                            : "Shows your motorhome without a rear rack. The bike rack location is hidden.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                }
                .tint(Color.accentColor)

                if profile.hasBikeRack {
                    Toggle(isOn: boolBinding(for: \.garageLimitIncludesBikeRack, on: profile)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include bike rack in garage limit")
                                .font(.subheadline.weight(.medium))
                            Text(profile.garageLimitIncludesBikeRack
                                ? "Garage limit totals items in Garage and Bike Rack zones."
                                : "Garage limit totals items in the Garage zone only (typical if your plate names the under-bed box).")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                    }
                    .tint(Color.accentColor)
                    Text("All items still count toward MAM and axle estimates. Bike rack axle impact is unchanged.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        AppSettingsSection(
            "Tow bar",
            caption: "When you tow a caravan or trailer behind your motorhome."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Toggle(isOn: boolBinding(for: \.usesManualTowBarLoad, on: profile)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I have a tow bar")
                            .font(.subheadline.weight(.medium))
                        Text("Include tow bar load in rear axle and gross weight estimates. Enter the measured downforce per trip when you record it — the app does not estimate it.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.accentColor)

                if profile.usesManualTowBarLoad {
                    AppLabeledNumberField(
                        "Max tow bar load (kg)",
                        caption: "Maximum nose weight your motorhome tow bar can take",
                        value: binding(for: \.maxTowBarKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                }
            }
        }

        motorhomeWeightFactors(profile)
    }

    @ViewBuilder
    private func motorhomeWeightFactors(_ profile: VehicleProfile) -> some View {
        AppCollapsibleSettingsSection(
            "Axle load factors",
            caption: "Kg added to each axle per kg of item. Cab ahead of the front axle; Middle between axles; Rear above the rear; Garage and bike rack behind the rear.",
            isExpanded: $isWeightFactorsExpanded
        ) {
            motorhomeFactorPair(profile, zone: "Cab (ahead of front axle)", front: \.mhFactorDriverFront, rear: \.mhFactorDriverRear)
            motorhomeFactorPair(profile, zone: "Middle (between axles)", front: \.mhFactorCentralFront, rear: \.mhFactorCentralRear)
            motorhomeFactorPair(profile, zone: "Rear (above rear axle)", front: \.mhFactorBackFront, rear: \.mhFactorBackRear)
            motorhomeFactorPair(profile, zone: "Garage (behind rear axle)", front: \.mhFactorGarageFront, rear: \.mhFactorGarageRear)
            if profile.hasBikeRack {
                motorhomeFactorPair(profile, zone: "Bike rack (rear overhang)", front: \.mhFactorBikeRackFront, rear: \.mhFactorBikeRackRear)
            }

            AppSecondaryButton("Reset axle factors to defaults") {
                viewModel.resetMotorhomeFactors(profile: profile, in: modelContext)
            }
        }
    }

    private static let motorhomeAxleSplitFieldMaxWidth: CGFloat = 120

    @ViewBuilder
    private func motorhomeAxleWeighbridgeFields(_ profile: VehicleProfile) -> some View {
        if usePadLayout {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppAlignedLabeledNumberFieldRow(
                    left: AppLabeledNumberField(
                        "Front axle (kg)",
                        caption: "From your weighbridge ticket — baseline before trip items",
                        value: binding(for: \.weighbridgeFrontAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    ),
                    right: AppLabeledNumberField(
                        "Rear axle (kg)",
                        caption: "From your weighbridge ticket — baseline before trip items",
                        value: binding(for: \.weighbridgeRearAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                )
                AppAlignedLabeledNumberFieldRow(
                    left: AppLabeledNumberField(
                        "Max front axle (kg)",
                        caption: "Plated front axle limit",
                        value: binding(for: \.maxFrontAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    ),
                    right: AppLabeledNumberField(
                        "Max rear axle (kg)",
                        caption: "Plated rear axle limit",
                        value: binding(for: \.maxRearAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                )
                HStack(alignment: .top, spacing: AppScreenMetrics.fieldSpacing) {
                    motorhomeSecondaryAxleNumberField(
                        "Front axle split (%)",
                        caption: "When axle weights are not entered",
                        value: binding(for: \.axleSplitFrontPercent, on: profile),
                        maxWidth: Self.motorhomeAxleSplitFieldMaxWidth
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
        } else {
            HStack(alignment: .top, spacing: AppScreenMetrics.fieldSpacing) {
                VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                    AppLabeledNumberField(
                        "Front axle (kg)",
                        caption: "From your weighbridge ticket — baseline before trip items",
                        value: binding(for: \.weighbridgeFrontAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                    AppLabeledNumberField(
                        "Max front axle (kg)",
                        caption: "Plated front axle limit",
                        value: binding(for: \.maxFrontAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                    motorhomeSecondaryAxleNumberField(
                        "Front axle split (%)",
                        caption: "When axle weights are not entered",
                        value: binding(for: \.axleSplitFrontPercent, on: profile),
                        maxWidth: Self.motorhomeAxleSplitFieldMaxWidth
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                    AppLabeledNumberField(
                        "Rear axle (kg)",
                        caption: "From your weighbridge ticket — baseline before trip items",
                        value: binding(for: \.weighbridgeRearAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                    AppLabeledNumberField(
                        "Max rear axle (kg)",
                        caption: "Plated rear axle limit",
                        value: binding(for: \.maxRearAxleKg, on: profile),
                        fractionDigitsUpperBound: 0
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func motorhomeSecondaryAxleNumberField(
        _ title: String,
        caption: String,
        value: Binding<Double>,
        maxWidth: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)
            AppBoundedNumberField(value: value, fractionDigitsUpperBound: 0)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    @ViewBuilder
    private func motorhomeFactorPair(
        _ profile: VehicleProfile,
        zone: String,
        front: ReferenceWritableKeyPath<VehicleProfile, Double>,
        rear: ReferenceWritableKeyPath<VehicleProfile, Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
            Text(zone)
                .font(.subheadline.weight(.semibold))
            AppFactorField(accentTitle: "Front axle", caption: "Kg added to front axle per kg of item", value: binding(for: front, on: profile))
            AppFactorField(accentTitle: "Rear axle", caption: "Kg added to rear axle per kg of item", value: binding(for: rear, on: profile))
        }
        .padding(.bottom, AppScreenMetrics.tinySpacing)
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<VehicleProfile, Double>, on profile: VehicleProfile) -> Binding<Double> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                viewModel.save(modelContext)
            }
        )
    }

    private func stringBinding(for keyPath: ReferenceWritableKeyPath<VehicleProfile, String>, on profile: VehicleProfile) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                viewModel.save(modelContext)
            }
        )
    }

    private func boolBinding(for keyPath: ReferenceWritableKeyPath<VehicleProfile, Bool>, on profile: VehicleProfile) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                viewModel.save(modelContext)
            }
        )
    }

    private func plateScanPickerMessage(for kind: VehicleKind) -> String {
        switch kind {
        case .caravan:
            return "Photograph the manufacturer plate so manufacturer, model, MTPLM/MAM, MIRO/MRO, axle limits, VIN, tyre size, pressure and wheel nut torque can be suggested."
        case .motorhome:
            return "Photograph the manufacturer plate so manufacturer, model, MAM, GTW, MRO, axle limits, VIN, body/cell number, tyre size and pressure can be suggested."
        }
    }

    private func plateScanControlsMessage(for kind: VehicleKind) -> String {
        switch kind {
        case .caravan:
            return "Photograph the manufacturer plate to suggest manufacturer, model, MTPLM/MAM, MIRO/MRO, hitch or axle limits, VIN, tyre size, pressure and wheel nut torque. Review before applying. The photo stays here so you can check which plate was scanned."
        case .motorhome:
            return "Photograph the manufacturer plate to suggest manufacturer, model, MAM, GTW, MRO, axle limits, VIN, body/cell number, tyre size and pressure. Review before applying. The photo stays here so you can check which plate was scanned."
        }
    }

    @ViewBuilder
    private func vehicleLookupControls(for profile: VehicleProfile) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Look up MOT, tax and vehicle details for this registration. Review before copying make or model into Settings.")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)

            AppSecondaryButton("Look up vehicle") {
                lookupVehicle(for: profile)
            }
            .disabled(isLookingUpVehicle || isAnalyzingPlate || isAnalyzingVINChip)

            if isLookingUpVehicle {
                ProgressView("Looking up vehicle…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let vehicleLookupError {
                AppWarningBanner(message: vehicleLookupError)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Look up registration for \(profile.kind.displayName)")
    }

    @ViewBuilder
    private func plateScanControls(for profile: VehicleProfile) -> some View {
        let attachedPlateImage = profile.manufacturerPlatePhotoFileName.isEmpty
            ? nil
            : VehiclePlatePhotoStore.loadImage(for: profile)

        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text(plateScanControlsMessage(for: profile.kind))
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)

            if let attachedPlateImage {
                HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                    ManufacturerPlateThumbnail(image: attachedPlateImage) {
                        platePreviewImage = attachedPlateImage
                    }

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text("Plate photo attached")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap the thumbnail to check which plate was scanned.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Remove photo", role: .destructive) {
                            VehiclePlatePhotoStore.delete(for: profile)
                            viewModel.save(modelContext)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.top, 2)
                    }
                }
            }

            AppSecondaryButton(attachedPlateImage == nil ? "Scan plate photo" : "Replace plate photo") {
                plateAnalysisError = nil
                showPlateSourcePicker = true
            }
            .disabled(isAnalyzingPlate || isAnalyzingVINChip)
            .accessibilityLabel(
                attachedPlateImage == nil
                    ? "Scan plate for \(profile.kind.displayName)"
                    : "Replace plate photo for \(profile.kind.displayName)"
            )

            if isAnalyzingPlate {
                ProgressView("Analysing plate photo…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let plateAnalysisError {
                AppWarningBanner(message: plateAnalysisError)
            }
        }
    }

    @ViewBuilder
    private func vinChipScanControls(for profile: VehicleProfile) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Photograph the CRiS VIN Chip sticker or QR code (window or gas locker) to fill the VIN. Optionally save the photo to Documents.")
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)

            AppSecondaryButton("Scan CRiS VIN Chip") {
                vinChipAnalysisError = nil
                showVINChipSourcePicker = true
            }
            .disabled(isAnalyzingPlate || isAnalyzingVINChip)

            if isAnalyzingVINChip {
                ProgressView("Analysing VIN Chip photo…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let vinChipAnalysisError {
                AppWarningBanner(message: vinChipAnalysisError)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scan CRiS VIN Chip for \(profile.kind.displayName)")
    }

    private func analyzePlateImage(_ image: UIImage) {
        isAnalyzingPlate = true
        plateAnalysisError = nil
        plateReviewItem = nil

        Task {
            do {
                let suggestions = try await VehiclePlateOCR.analyze(image: image)
                await MainActor.run {
                    isAnalyzingPlate = false
                    if suggestions.hasAnySuggestion {
                        plateReviewItem = VehiclePlateReviewItem(suggestions: suggestions, image: image)
                    } else {
                        plateAnalysisError = suggestions.confidenceNotes.first
                            ?? "No plate values could be recognised. Try a closer photo with the plate filling the frame."
                    }
                }
            } catch {
                await MainActor.run {
                    isAnalyzingPlate = false
                    plateAnalysisError = "Plate analysis failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func analyzeVINChipImage(_ image: UIImage) {
        isAnalyzingVINChip = true
        vinChipAnalysisError = nil
        vinChipReviewItem = nil

        Task {
            do {
                let suggestions = try await CRiSVINChipOCR.analyze(image: image)
                await MainActor.run {
                    isAnalyzingVINChip = false
                    vinChipAnalysisError = nil
                    vinChipReviewItem = CRiSVINChipReviewItem(suggestions: suggestions, image: image)
                }
            } catch {
                await MainActor.run {
                    isAnalyzingVINChip = false
                    vinChipAnalysisError = "VIN Chip analysis failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func lookupVehicle(for profile: VehicleProfile) {
        vehicleLookupError = nil
        isLookingUpVehicle = true
        let registration = profile.registrationMark
        Task {
            do {
                let result = try await vehicleLookup.lookup(registration: registration, forceRefresh: false)
                isLookingUpVehicle = false
                profile.registrationMark = result.displayRegistration
                viewModel.save(modelContext)
                vehicleLookupReviewItem = VehicleLookupReviewItem(result: result)
            } catch {
                isLookingUpVehicle = false
                if let lookupError = error as? VehicleLookupError {
                    vehicleLookupError = lookupError.errorDescription
                } else {
                    vehicleLookupError = VehicleLookupError.unexpectedResponse.errorDescription
                }
            }
        }
    }

    private func applyVehicleLookup(
        _ result: VehicleLookupResult,
        applyMake: Bool,
        applyModel: Bool,
        to profile: VehicleProfile
    ) {
        if !result.displayRegistration.isEmpty {
            profile.registrationMark = result.displayRegistration
        }
        if applyMake, let make = result.make?.trimmingCharacters(in: .whitespacesAndNewlines), !make.isEmpty {
            profile.manufacturer = make
        }
        if applyModel, let model = result.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
            profile.modelName = model
        }
        if let year = result.firstRegistrationYear {
            profile.firstRegistrationYear = year
        }
        if let lastMOT = result.lastMotDate {
            profile.lastMotDate = lastMOT
        }
        if let expiry = result.motExpiryDate {
            profile.motExpiryDate = expiry
        }
        viewModel.save(modelContext)
    }

    private func applyPlateSuggestions(_ suggestions: VehiclePlateSuggestions, image: UIImage, to profile: VehicleProfile) {
        if let manufacturer = suggestions.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines), !manufacturer.isEmpty {
            profile.manufacturer = manufacturer
        }
        if let modelName = suggestions.modelName?.trimmingCharacters(in: .whitespacesAndNewlines), !modelName.isEmpty {
            profile.modelName = modelName
        }
        if let vin = suggestions.vinChassisNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !vin.isEmpty {
            profile.vinChassisNumber = vin
        }
        if let mtplm = suggestions.mtplmOrMamKg, mtplm > 0 {
            profile.mtplmKg = mtplm
        }
        if profile.kind == .motorhome {
            if let cell = suggestions.bodyCellNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !cell.isEmpty {
                profile.bodyCellNumber = cell
            }
            if let gtw = suggestions.gtwKg, gtw > 0 {
                profile.gtwKg = gtw
            }
        }
        if let miro = suggestions.miroOrMroKg, miro > 0 {
            profile.baseWeightKg = miro
        }
        if profile.kind == .caravan, let nose = suggestions.hitchOrNoseKg, nose > 0 {
            profile.caravanMaxNoseKg = nose
        }
        if profile.kind == .motorhome {
            if let front = suggestions.maxFrontAxleKg, front > 0 {
                profile.maxFrontAxleKg = front
            }
            if let rear = suggestions.maxRearAxleKg, rear > 0 {
                profile.maxRearAxleKg = rear
            }
        }
        if profile.kind == .caravan {
            profile.applyCaravanPlateTorque(
                steelNm: suggestions.wheelNutTorqueSteelNm,
                alloyNm: suggestions.wheelNutTorqueAlloyNm
            )
        }

        TyreStore.applyPlateTyreSpec(
            to: profile,
            tyreSize: suggestions.tyreSize,
            recommendedPressurePSI: suggestions.tyrePressurePSI,
            in: modelContext
        )

        try? VehiclePlatePhotoStore.save(image: image, to: profile)
        viewModel.save(modelContext)
    }

    private func applyVINChipResult(vin: String, savePhoto: Bool, image: UIImage, to profile: VehicleProfile) {
        let trimmedVIN = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVIN.isEmpty {
            profile.vinChassisNumber = trimmedVIN
            viewModel.save(modelContext)
        }

        guard savePhoto else { return }

        let record = DocumentStore.createRecord(for: profile.id, in: modelContext)
        let notes = trimmedVIN.isEmpty ? "CRiS VIN Chip photo" : "VIN: \(trimmedVIN)"
        DocumentStore.save(
            record: record,
            title: "CRiS VIN Chip",
            category: .vinChassisInformation,
            dateAdded: Date(),
            expiryDate: nil,
            reminderDate: nil,
            notes: notes,
            in: modelContext
        )

        if let draft = try? MaintenanceAttachmentStore.draft(
            image: image,
            fileType: .photo,
            displayName: "CRiS VIN Chip"
        ) {
            try? MaintenanceAttachmentStore.save(draft: draft, to: .document(record), in: modelContext)
        }
    }

    private func insuranceStartDateBinding(on profile: VehicleProfile) -> Binding<Date> {
        Binding(
            get: { profile.insuranceStartDate ?? Calendar.current.startOfDay(for: Date()) },
            set: { newValue in
                profile.insuranceStartDate = Calendar.current.startOfDay(for: newValue)
                viewModel.save(modelContext)
                WarrantyStore.syncInsuranceRenewalEvents(for: profile, in: modelContext)
            }
        )
    }

    private func ukMarketBinding(for profile: VehicleProfile) -> Binding<Bool> {
        Binding(
            get: { profile.warrantyUKMarket },
            set: { newValue in
                profile.warrantyUKMarket = newValue
                if !newValue {
                    WarrantyStore.clearManufacturerTemplate(for: profile.id, in: modelContext)
                }
                viewModel.save(modelContext)
            }
        )
    }

    private func noseSafeZoneBasisBinding(on profile: VehicleProfile) -> Binding<NoseSafeZoneBasis> {
        Binding(
            get: { profile.noseSafeZoneBasis },
            set: { newValue in
                profile.noseSafeZoneBasis = newValue
                viewModel.save(modelContext)
            }
        )
    }

    /// Enough caravan data to evaluate the 5% nose band used on the Summary tab (matches “Nose weight safe zone”).
    private static func hasCaravanContextForFivePercentRule(_ profile: VehicleProfile) -> Bool {
        switch profile.noseSafeZoneBasis {
        case .mtplm:
            return profile.mtplmKg > 0
        case .ladenWeight:
            return profile.calculationBaseWeightKg > 0
        }
    }

    private static func carTowBallFivePercentConflictMessage(profile: VehicleProfile, summary: WeightSummary) -> String {
        let minNose = Formatters.kg(summary.towBallMinKg)
        let limit = Formatters.kg(profile.effectiveMaxTowBallKg)
        return "The 5% minimum nose weight (\(minNose)) meets or exceeds your effective limit (\(limit))—the lower of your car tow ball and caravan hitch limits. You may need a higher car limit, a higher hitch rating (only if the car allows), or a lighter caravan."
    }

    private func openSystemSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
#endif
    }

    private static func carTowBallFivePercentHintText(profile: VehicleProfile, summary: WeightSummary) -> String {
        let minNose = Formatters.kg(summary.towBallMinKg)
        let maxNose = Formatters.kg(summary.towBallMaxKg)
        let basis = profile.noseSafeZoneBasis == .mtplm ? "MTPLM" : "laden weight"
        let effective = profile.effectiveMaxTowBallKg
        if effective > 0 {
            return "At your current inputs the recommended nose band is about \(minNose) to \(maxNose) (5%–7% of \(basis), same as the Summary tab). Your effective limit (\(Formatters.kg(effective))) is the lower of your car and hitch ratings—it is above the \(minNose) (5%) end of that band."
        }
        return "At your current inputs the recommended nose band is about \(minNose) to \(maxNose) (5%–7% of \(basis), same as the Summary tab). Enter your tow ball and hitch limits so the app can warn you if those caps conflict with that 5% minimum."
    }

}

// MARK: - Add vehicle sheet

private struct AddVehicleSheet: View {
    @Binding var name: String
    @Binding var kind: VehicleKind
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppLabeledTextField("Name", placeholder: "e.g. Our Motorhome", text: $name)

                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        Text("Vehicle type")
                            .font(.subheadline.weight(.semibold))
                        Picker("Vehicle type", selection: $kind) {
                            ForEach(VehicleKind.allCases) { vehicleKind in
                                Label(vehicleKind.displayName, systemImage: vehicleKind.systemImage)
                                    .tag(vehicleKind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    AppPrimaryButton("Add vehicle") { onAdd() }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Add vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct SettingsNavigationTitleModifier: ViewModifier {
    @Environment(\.padTopTabBarActive) private var padTopTabBarActive

    func body(content: Content) -> some View {
        if padTopTabBarActive {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content.appPrincipalTabTitle("Settings")
        }
    }
}
