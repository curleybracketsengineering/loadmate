import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [SetupConfig]

    @StateObject private var viewModel = SettingsViewModel()
    @State private var resolvedConfig: SetupConfig?

    var body: some View {
        NavigationStack {
            Group {
                if let config = resolvedConfig {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                            AppHeroSection(
                                systemImage: "gearshape",
                                title: "Caravan Configuration",
                                subtitle: "Set your caravan's weight specifications"
                            )

                            AppLabeledNumberField(
                                "Base Weight (kg)",
                                caption: "The unladen weight of your caravan",
                                value: binding(for: \.baseWeightKg, on: config),
                                fractionDigitsUpperBound: 0
                            )

                            AppLabeledNumberField(
                                "MTPLM (kg)",
                                caption: "Maximum Technically Permissible Laden Mass",
                                value: binding(for: \.mtplmKg, on: config),
                                fractionDigitsUpperBound: 0
                            )

                            AppSectionDivider()

                            AppLabeledNumberField(
                                "Car Max Tow Ball Weight (kg)",
                                caption: "Maximum tow ball weight your car can handle",
                                value: binding(for: \.carMaxTowBallKg, on: config),
                                fractionDigitsUpperBound: 0
                            )

                            AppSectionDivider()

                            AppSectionHeading(
                                "Weight Factors",
                                caption: "Adjust how each location affects nose weight. Positive values increase nose weight, negative values decrease it."
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

                            Text("This app is an estimator only. Always physically measure caravan and nose weight.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .padding(.top, AppScreenMetrics.tinySpacing)

                            VStack(spacing: AppScreenMetrics.controlSpacing) {
                                AppSecondaryButton("Reset zone factors to defaults") {
                                    viewModel.resetFactors(config: config, in: modelContext)
                                }

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
