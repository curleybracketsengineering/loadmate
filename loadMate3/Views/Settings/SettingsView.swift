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
                            TextField("Base Weight (kg)", value: binding(for: \.baseWeightKg, on: config), format: .number)
                                .keyboardType(.decimalPad)
                            TextField("MTPLM (kg)", value: binding(for: \.mtplmKg, on: config), format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Car Max Tow Ball (kg)", value: binding(for: \.carMaxTowBallKg, on: config), format: .number)
                                .keyboardType(.decimalPad)
                        }

                        Section("Zone Factors") {
                            TextField("Front Locker", value: binding(for: \.factorFrontLocker, on: config), format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Front", value: binding(for: \.factorFront, on: config), format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Middle", value: binding(for: \.factorMiddle, on: config), format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Rear", value: binding(for: \.factorRear, on: config), format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Bike Rack", value: binding(for: \.factorBikeRack, on: config), format: .number)
                                .keyboardType(.decimalPad)

                            Button("Reset Defaults") {
                                viewModel.resetFactors(config: config, in: modelContext)
                            }
                            .foregroundStyle(.orange)
                        }

                        Section("Disclaimer") {
                            Text("This app is an estimator only. Always physically measure caravan and nose weight.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
}
