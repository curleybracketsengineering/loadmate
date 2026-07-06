import SwiftUI
import SwiftData

struct SettingsView: View {
    var onNavigateToSummary: (() -> Void)?

    @Environment(\.usePadLayout) private var usePadLayout
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\VehicleProfile.sortOrder)]) private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var cloudSync = CloudSyncMonitor()
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

                            aboutSection()

                            iCloudSyncSection()

                            Text("This app is an estimator only. Always physically measure weight and axle loads on a weighbridge.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .padding(.top, AppScreenMetrics.tinySpacing)

                            VStack(spacing: AppScreenMetrics.controlSpacing) {
                                AppPrimaryButton("Save Configuration", systemImage: "checkmark.circle.fill") {
                                    guard viewModel.save(modelContext) else { return }
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
            .appPrincipalTabTitle("Settings")
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
    }

    private func profileSubtitle(_ profile: VehicleProfile) -> String {
        "\(profile.kind.displayName) — \(profile.name)"
    }

    private static let developerEmail = "smatheson6@icloude.com"

    @ViewBuilder
    private func iCloudSyncSection() -> some View {
        AppSettingsSection(
            "iCloud sync",
            caption: "Keep your data consistent across your own iPhone and iPad."
        ) {
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
        }
    }

    @ViewBuilder
    private func aboutSection() -> some View {
        AppSettingsSection(
            "About",
            caption: "Who built LoadMate and why it exists."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text(
                    """
                    LoadMate was built for you by Scott Matheson. After four decades in software development, I kept seeing hobby apps — caravanning and motorhomes included — that were either poorly made or mainly about making money. I wanted to put that experience toward something genuinely useful: a free utility to help us all load more safely and sensibly.

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
        AppSettingsSection("Motorhome", caption: "Limits from your vehicle plate (MAM and axle weights).") {
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
                            "MRO (kg)",
                            caption: "Mass in Running Order — used when no weighbridge reading is entered",
                            value: binding(for: \.baseWeightKg, on: profile),
                            fractionDigitsUpperBound: 0
                        )
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
                        Text("Show a Tow bar field on the Load tab. Enter the measured downforce per trip — the app adds it to rear axle and gross weight; it does not estimate it.")
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

    private func boolBinding(for keyPath: ReferenceWritableKeyPath<VehicleProfile, Bool>, on profile: VehicleProfile) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
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
