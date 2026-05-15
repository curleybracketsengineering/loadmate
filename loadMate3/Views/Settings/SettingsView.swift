import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [SetupConfig]

    @StateObject private var viewModel = SettingsViewModel()
    @State private var resolvedConfig: SetupConfig?
    @State private var isWeightFactorsExpanded = false

    var body: some View {
        NavigationStack {
            Group {
                if let config = resolvedConfig {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                            AppHeroSection(
                                systemImage: "gearshape",
                                title: "Settings",
                                subtitle: "Caravan, vehicle, and loading adjustments"
                            )

                            AppSettingsSection(
                                "Caravan",
                                caption: "Weights from your caravan plate or handbook."
                            ) {
                                VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                                    AppLabeledNumberField(
                                        "MTPLM (kg)",
                                        caption: "Maximum Technically Permissible Laden Mass",
                                        value: binding(for: \.mtplmKg, on: config),
                                        fractionDigitsUpperBound: 0
                                    )

                                    AppLabeledNumberField(
                                        "MIRO (kg)",
                                        caption: "Mass in Running Order from your handbook — used when no weighbridge weight is entered",
                                        value: binding(for: \.baseWeightKg, on: config),
                                        fractionDigitsUpperBound: 0
                                    )

                                    AppLabeledNumberField(
                                        "Weighbridge weight (kg)",
                                        caption: "Actual caravan weight before trip items are loaded — used instead of MIRO when entered",
                                        value: binding(for: \.weighbridgeWeightKg, on: config),
                                        fractionDigitsUpperBound: 0
                                    )

                                    AppLabeledNumberField(
                                        "Caravan hitch limit (kg)",
                                        caption: "Maximum nose weight on the caravan hitch",
                                        value: binding(for: \.caravanMaxNoseKg, on: config),
                                        fractionDigitsUpperBound: 0
                                    )
                                }
                            }

                            AppSettingsSection(
                                "Vehicle",
                                caption: "Your car’s towing specification."
                            ) {
                                AppLabeledNumberField(
                                    "Car tow ball limit (kg)",
                                    caption: "Maximum tow ball weight your car can handle",
                                    value: binding(for: \.carMaxTowBallKg, on: config),
                                    fractionDigitsUpperBound: 0
                                )
                            }

                            AppSettingsSection("Location") {
                                Text("Front locker, front, middle, rear, and bike rack, used on the Locations tab when assigning items.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            AppCollapsibleSettingsSection(
                                "Weight factors",
                                caption: "Adjust how each location affects nose weight. Positive values increase nose weight, negative values decrease it.",
                                isExpanded: $isWeightFactorsExpanded
                            ) {
                                Text("Baseline nose weight is calculated from total caravan weight using the percentage below. For your own caravan, we suggest checking nose weight when the caravan is at a known weight for example, just after a weighbridge visit, then adjusting this value slightly for a more accurate estimate as your load changes.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)

                                AppFactorField(
                                    accentTitle: "Base nose weight (%)",
                                    caption: "Percentage of total caravan weight used for the baseline nose estimate",
                                    value: binding(for: \.noseWeightBasePercent, on: config)
                                )

                                AppFactorField(
                                    accentTitle: "Front Boot (Locker)",
                                    caption: "Items at the very front of the caravan",
                                    value: binding(for: \.factorFrontLocker, on: config)
                                )

                                AppFactorField(
                                    accentTitle: "Front",
                                    caption: "Front seating and forward storage areas",
                                    value: binding(for: \.factorFront, on: config)
                                )

                                AppFactorField(
                                    accentTitle: "Middle",
                                    caption: "Over or near the axle",
                                    value: binding(for: \.factorMiddle, on: config)
                                )

                                AppFactorField(
                                    accentTitle: "Back",
                                    caption: "Rear cupboards and under bed area",
                                    value: binding(for: \.factorRear, on: config)
                                )

                                AppFactorField(
                                    accentTitle: "Bike Rack",
                                    caption: "Very rear — bumper or rack behind axle",
                                    value: binding(for: \.factorBikeRack, on: config)
                                )

                                AppSecondaryButton("Reset weight factors to defaults") {
                                    viewModel.resetFactors(config: config, in: modelContext)
                                }
                            }

                            Text("This app is an estimator only. Always physically measure caravan and nose weight.")
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
        .task(id: configs.count) {
            resolvedConfig = viewModel.ensureConfig(in: modelContext, existing: configs.first)
        }
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<SetupConfig, Double>, on config: SetupConfig) -> Binding<Double> {
        Binding(
            get: { config[keyPath: keyPath] },
            set: { newValue in
                config[keyPath: keyPath] = newValue
                viewModel.save(modelContext)
            }
        )
    }
}
