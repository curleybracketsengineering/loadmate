import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query private var configs: [SetupConfig]
    @Query private var loadedItems: [LoadedItem]
    @StateObject private var viewModel = SummaryViewModel()
    private var refreshToken: String {
        let configSignature = configs.first.map {
            "\($0.baseWeightKg)-\($0.mtplmKg)-\($0.carMaxTowBallKg)-\($0.factorFrontLocker)-\($0.factorFront)-\($0.factorMiddle)-\($0.factorRear)-\($0.factorBikeRack)"
        } ?? "no-config"

        let itemSignature = loadedItems.map {
            "\($0.id.uuidString)-\($0.quantity)-\($0.zoneRaw)-\($0.item?.weightKg ?? 0)"
        }.joined(separator: "|")

        return "\(configSignature)|\(itemSignature)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let summary = viewModel.summary, let config = configs.first {
                    List {
                        Section("Weights") {
                            LabeledContent("Loaded", value: Formatters.kg(summary.loadedWeightKg))
                            LabeledContent("Total", value: Formatters.kg(summary.totalWeightKg))
                            LabeledContent("MTPLM", value: Formatters.kg(config.mtplmKg))
                            LabeledContent("Remaining", value: Formatters.kg(summary.availableWeightKg))
                        }

                        Section("Nose Weight") {
                            LabeledContent("Estimate", value: Formatters.kg(summary.estimatedNoseWeightKg))
                            LabeledContent("Recommended Min (5%)", value: Formatters.kg(summary.towBallMinKg))
                            LabeledContent("Recommended Max (7%)", value: Formatters.kg(summary.towBallMaxKg))
                            LabeledContent("Car Limit", value: Formatters.kg(config.carMaxTowBallKg))
                        }

                        Section("Safety") {
                            StatusRow(title: "Over MTPLM", isWarning: summary.isOverMTPLM)
                            StatusRow(title: "Over Tow-Ball Limit", isWarning: summary.isOverTowBallLimit)
                            StatusRow(title: "Nose Below 5%", isWarning: summary.isNoseBelowRecommended)
                            StatusRow(title: "Nose Above 7%", isWarning: summary.isNoseAboveRecommended)
                        }
                    }
                } else {
                    ContentUnavailableView("Setup Required", systemImage: "exclamationmark.triangle", description: Text("Open Settings and enter Base Weight, MTPLM, and Tow-Ball limit."))
                }
            }
            .navigationTitle("Summary")
            .task(id: refreshToken) {
                viewModel.refresh(config: configs.first, loadedItems: loadedItems)
            }
        }
    }
}

private struct StatusRow: View {
    let title: String
    let isWarning: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isWarning ? .red : .green)
        }
    }
}
