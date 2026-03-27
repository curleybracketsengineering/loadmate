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
                    Form {
                        Section("Setup") {
                            labeledNumberField("Base Weight (kg)", keyPath: \.baseWeightKg, on: config)
                            labeledNumberField("MTPLM (kg)", keyPath: \.mtplmKg, on: config)
                            labeledNumberField("Car Max Tow Ball (kg)", keyPath: \.carMaxTowBallKg, on: config)
                        }

                        Section("Zone Factors") {
                            labeledNumberField("Front Locker", keyPath: \.factorFrontLocker, on: config)
                            labeledNumberField("Front", keyPath: \.factorFront, on: config)
                            labeledNumberField("Middle", keyPath: \.factorMiddle, on: config)
                            labeledNumberField("Rear", keyPath: \.factorRear, on: config)
                            labeledNumberField("Bike Rack", keyPath: \.factorBikeRack, on: config)

                            Button("Reset Defaults") {
                                viewModel.resetFactors(config: config, in: modelContext)
                            }
                            .foregroundStyle(AppColors.actionCaution)
                        }

                        Section("Disclaimer") {
                            Text("This app is an estimator only. Always physically measure caravan and nose weight.")
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Settings")
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

    @ViewBuilder
    private func labeledNumberField(_ title: String, keyPath: ReferenceWritableKeyPath<SetupConfig, Double>, on config: SetupConfig) -> some View {
        LabeledContent(title) {
            TextField("", value: binding(for: keyPath, on: config), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
