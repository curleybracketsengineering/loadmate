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
                    ScrollView {
                        VStack(spacing: 16) {
                            statusBanner(summary: summary)

                            currentWeightCard(summary: summary, config: config)

                            noseWeightCard(summary: summary, config: config)
                        }
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.vertical, 16)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(AppColors.backgroundSecondary)
                } else {
                    ContentUnavailableView(
                        "Setup required",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Open Settings and enter base weight, MTPLM, and tow-ball limit.")
                    )
                    .background(AppColors.backgroundSecondary)
                }
            }
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.large)
            .task(id: refreshToken) {
                viewModel.refresh(config: configs.first, loadedItems: loadedItems)
            }
        }
    }

    private func statusBanner(summary: WeightSummary) -> some View {
        let (title, background): (String, Color) = {
            if summary.isOverMTPLM {
                return ("OVER CARAVAN", AppColors.red)
            }
            if summary.isOverallSafe {
                return ("SAFE", AppColors.green)
            }
            return ("OVER LOADED TOW BALL", AppColors.red)
        }()

        return Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.white)
            .tracking(1.2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("Status: \(title)")
    }

    private func currentWeightCard(summary: WeightSummary, config: SetupConfig) -> some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Current Weight")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(Formatters.kg(summary.totalWeightKg))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(summary.isOverMTPLM ? AppColors.red : AppColors.green)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                mtplmProgressBar(fill: CGFloat(summary.mtplmFillFraction(config: config)))

                HStack {
                    Text("MTPLM: \(stripKgSuffix(Formatters.kg(config.mtplmKg))) kg")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("Available: \(stripKgSuffix(Formatters.kg(summary.availableWeightKg))) kg")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(summary.availableWeightKg >= 0 ? AppColors.green : AppColors.red)
                }
            }
        }
    }

    private func noseWeightCard(summary: WeightSummary, config: SetupConfig) -> some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nose Weight")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(spacing: 12) {
                    HStack {
                        Text("Base (6%)")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(Formatters.kg(summary.baseNoseSixPercentKg))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    HStack {
                        Text("Location Impact")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(signedKg(summary.locationImpactKg))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                summary.locationImpactKg < 0
                                    ? AppColors.red
                                    : (summary.locationImpactKg > 0 ? AppColors.green : AppColors.textPrimary)
                            )
                    }

                    Rectangle()
                        .fill(AppColors.separator.opacity(0.5))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calculated Nose Weight")
                            .font(.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(Formatters.kg(summary.estimatedNoseWeightKg))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.isOverTowBallLimit ? AppColors.red : AppColors.blue)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                let carLimitOverridesMin = config.carMaxTowBallKg > 0 && config.carMaxTowBallKg < summary.towBallMinKg
                let carLimitOverridesMax = config.carMaxTowBallKg > 0 && config.carMaxTowBallKg < summary.towBallMaxKg

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(carLimitOverridesMin ? "Car Limit" : "Min (5%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(Formatters.kg(carLimitOverridesMin ? config.carMaxTowBallKg : summary.towBallMinKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMin ? AppColors.red : AppColors.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(AppColors.separator.opacity(0.45))
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(carLimitOverridesMax ? "Car Limit" : "Max (7%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(Formatters.kg(carLimitOverridesMax ? config.carMaxTowBallKg : summary.towBallMaxKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMax ? AppColors.red : AppColors.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 4)

                Text("Car Max Tow Ball: \(stripKgSuffix(Formatters.kg(config.carMaxTowBallKg))) kg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.blue)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(AppColors.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func mtplmProgressBar(fill: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.backgroundSecondary)
                Capsule()
                    .fill(AppColors.green)
                    .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
            }
        }
        .frame(height: 10)
        .accessibilityLabel("Progress toward MTPLM")
        .accessibilityValue("\(Int(fill * 100)) percent")
    }

    /// Shows kg with sign for near-zero impact values.
    private func signedKg(_ value: Double) -> String {
        let formatted = Formatters.oneDecimal.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
        if value < 0 {
            return "-\(formatted) kg"
        }
        if value > 0 {
            return "+\(formatted) kg"
        }
        return "0.0 kg"
    }

    private func stripKgSuffix(_ s: String) -> String {
        s.replacingOccurrences(of: " kg", with: "").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Card chrome

private struct SummaryCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}
