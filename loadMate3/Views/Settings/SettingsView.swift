import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\VehicleProfile.sortOrder)]) private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]

    @StateObject private var viewModel = SettingsViewModel()
    @State private var appState: AppState?
    @State private var editingProfile: VehicleProfile?
    @State private var isWeightFactorsExpanded = false
    @State private var showAddVehicle = false
    @State private var newVehicleName = ""
    @State private var newVehicleKind: VehicleKind = .caravan

    private var sortedProfiles: [VehicleProfile] {
        VehicleProfileStore.sortedProfiles(profiles)
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

                            vehicleProfilesSection(active: profile)

                            if profile.kind == .caravan {
                                caravanSettings(profile)
                            } else {
                                motorhomeSettings(profile)
                            }

                            Text("This app is an estimator only. Always physically measure weight and axle loads on a weighbridge.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .padding(.top, AppScreenMetrics.tinySpacing)

                            VStack(spacing: AppScreenMetrics.controlSpacing) {
                                AppPrimaryButton("Save Configuration", systemImage: "checkmark.circle.fill") {
                                    viewModel.save(modelContext)
                                }
                            }
                            .padding(.top, AppScreenMetrics.smallSpacing)
                        }
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.top, AppScreenMetrics.verticalScreenPadding)
                        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
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
        .task(id: profiles.count) {
            let boot = viewModel.bootstrap(in: modelContext, profiles: profiles, appState: appStates.first)
            appState = boot.appState
            editingProfile = VehicleProfileStore.activeProfile(profiles: boot.profiles, appState: boot.appState)
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
    }

    private func profileSubtitle(_ profile: VehicleProfile) -> String {
        "\(profile.kind.displayName) — \(profile.name)"
    }

    // MARK: - Profiles

    @ViewBuilder
    private func vehicleProfilesSection(active: VehicleProfile) -> some View {
        AppSettingsSection(
            "My vehicles",
            caption: "Switch between caravan and motorhome. Each has its own limits and load list."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                ForEach(sortedProfiles) { profile in
                    Button {
                        guard let state = appState else { return }
                        viewModel.setActiveProfile(profile, appState: state, in: modelContext)
                        editingProfile = profile
                    } label: {
                        HStack(spacing: AppScreenMetrics.controlSpacing) {
                            Image(systemName: profile.kind.systemImage)
                                .font(.body)
                                .foregroundStyle(profile.id == active.id ? Color.accentColor : Color.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                Text(profile.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                            }

                            Spacer()

                            if profile.id == active.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, AppScreenMetrics.tinySpacing)
                    }
                    .buttonStyle(.plain)
                }

                AppSecondaryButton("Add vehicle") {
                    showAddVehicle = true
                }

                if sortedProfiles.count > 1 {
                    AppSecondaryButton("Remove “\(active.name)”") {
                        guard let state = appState else { return }
                        viewModel.deleteProfile(active, profiles: profiles, appState: state, in: modelContext)
                        editingProfile = VehicleProfileStore.activeProfile(profiles: profiles, appState: state)
                    }
                }

                AppLabeledTextField(
                    "Vehicle name",
                    placeholder: "e.g. Bailey Pegasus",
                    text: nameBinding(for: active)
                )
            }
        }
    }

    // MARK: - Caravan

    @ViewBuilder
    private func caravanSettings(_ profile: VehicleProfile) -> some View {
        AppSettingsSection("Caravan", caption: "Weights from your caravan plate or handbook.") {
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

        AppSettingsSection("Vehicle", caption: "Your car’s towing specification.") {
            AppLabeledNumberField(
                "Car tow ball limit (kg)",
                caption: "Maximum tow ball weight your car can handle",
                value: binding(for: \.carMaxTowBallKg, on: profile),
                fractionDigitsUpperBound: 0
            )
        }

        locationSection(profile)

        caravanWeightFactors(profile)
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
            AppFactorField(accentTitle: "Bike Rack", caption: "Bumper or rack behind axle", value: binding(for: \.factorBikeRack, on: profile))

            AppSecondaryButton("Reset weight factors to defaults") {
                viewModel.resetCaravanFactors(profile: profile, in: modelContext)
            }
        }
    }

    // MARK: - Motorhome

    @ViewBuilder
    private func motorhomeSettings(_ profile: VehicleProfile) -> some View {
        AppSettingsSection("Motorhome", caption: "Limits from your vehicle plate (MAM and axle weights).") {
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

        AppSettingsSection(
            "Axle weighbridge",
            caption: "For best accuracy, enter front and rear axle weights from your weighbridge ticket."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppLabeledNumberField(
                    "Front axle (kg)",
                    caption: "Measured front axle load at a known weight",
                    value: binding(for: \.weighbridgeFrontAxleKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "Rear axle (kg)",
                    caption: "Measured rear axle load at a known weight",
                    value: binding(for: \.weighbridgeRearAxleKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "Front axle split (%)",
                    caption: "Estimated front share when axle weights are not entered",
                    value: binding(for: \.axleSplitFrontPercent, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "Max front axle (kg)",
                    caption: "Plated front axle limit",
                    value: binding(for: \.maxFrontAxleKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                AppLabeledNumberField(
                    "Max rear axle (kg)",
                    caption: "Plated rear axle limit",
                    value: binding(for: \.maxRearAxleKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
            }
        }

        AppSettingsSection(
            "Rear garage",
            caption: "Optional limit for the overhang garage box (often fitted after build). Leave at 0 if not applicable."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                AppLabeledNumberField(
                    "Max garage load (kg)",
                    caption: "Manufacturer limit for the garage structure — trip items in the Garage location are totalled against this",
                    value: binding(for: \.maxGarageKg, on: profile),
                    fractionDigitsUpperBound: 0
                )
                Text("Items in the Garage zone still count toward gross weight and rear axle estimates.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        locationSection(profile)

        motorhomeWeightFactors(profile)

        AppSettingsSection("Coming later") {
            Text("Towing a caravan or trailer behind your motorhome is planned for a future update.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
        }
    }

    @ViewBuilder
    private func motorhomeWeightFactors(_ profile: VehicleProfile) -> some View {
        AppCollapsibleSettingsSection(
            "Axle load factors",
            caption: "Kg added to each axle per kg of item. Front is above the front axle; Back above the rear; Garage behind the rear.",
            isExpanded: $isWeightFactorsExpanded
        ) {
            motorhomeFactorPair(profile, zone: "Driver (ahead of front axle)", front: \.mhFactorDriverFront, rear: \.mhFactorDriverRear)
            motorhomeFactorPair(profile, zone: "Front (above front axle)", front: \.mhFactorFrontFront, rear: \.mhFactorFrontRear)
            motorhomeFactorPair(profile, zone: "Central (between axles)", front: \.mhFactorCentralFront, rear: \.mhFactorCentralRear)
            motorhomeFactorPair(profile, zone: "Back (above rear axle)", front: \.mhFactorBackFront, rear: \.mhFactorBackRear)
            motorhomeFactorPair(profile, zone: "Garage (behind rear axle)", front: \.mhFactorGarageFront, rear: \.mhFactorGarageRear)

            AppSecondaryButton("Reset axle factors to defaults") {
                viewModel.resetMotorhomeFactors(profile: profile, in: modelContext)
            }
        }
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

    @ViewBuilder
    private func locationSection(_ profile: VehicleProfile) -> some View {
        let zones = profile.kind == .motorhome
            ? "Driver, front, central, back, and garage"
            : "Front locker, front, middle, rear, and bike rack"
        AppSettingsSection("Location") {
            Text("\(zones), used on the Locations tab when assigning items.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    private func nameBinding(for profile: VehicleProfile) -> Binding<String> {
        Binding(
            get: { profile.name },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                profile.name = trimmed.isEmpty ? profile.kind.displayName : trimmed
                viewModel.save(modelContext)
            }
        )
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
