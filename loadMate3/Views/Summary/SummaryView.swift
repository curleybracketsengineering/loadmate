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
                        VStack(spacing: AppScreenMetrics.sectionSpacing) {
                            statusBanner(summary: summary)

                            currentWeightCard(summary: summary, config: config)

                            noseWeightCard(summary: summary, config: config)
                        }
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.top, AppScreenMetrics.verticalScreenPadding)
                        .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(Color(.systemGroupedBackground))
                } else {
                    ContentUnavailableView(
                        "Setup required",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Open Settings and enter base weight, MTPLM, and tow-ball limit.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
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
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
            .accessibilityLabel("Status: \(title)")
    }

    private func currentWeightCard(summary: WeightSummary, config: SetupConfig) -> some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Current Weight")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSupporting)
                    Spacer()
                    Text(Formatters.kg(summary.totalWeightKg))
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(summary.isOverMTPLM ? AppColors.red : AppColors.green)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                mtplmProgressBar(fill: CGFloat(summary.mtplmFillFraction(config: config)))

                HStack {
                    Text("MTPLM: \(stripKgSuffix(Formatters.kg(config.mtplmKg))) kg")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                    Spacer()
                    Text("Available: \(stripKgSuffix(Formatters.kg(summary.availableWeightKg))) kg")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(summary.availableWeightKg >= 0 ? AppColors.green : AppColors.red)
                }
            }
        }
    }

    private func noseWeightCard(summary: WeightSummary, config: SetupConfig) -> some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Text("Nose Weight")
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    HStack {
                        Text("Base (6%)")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSupporting)
                        Spacer()
                        Text(Formatters.kg(summary.baseNoseSixPercentKg))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                    }

                    HStack {
                        Text("Location Impact")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSupporting)
                        Spacer()
                        Text(signedKg(summary.locationImpactKg))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                summary.locationImpactKg < 0
                                    ? AppColors.red
                                    : (summary.locationImpactKg > 0 ? AppColors.green : Color.primary)
                            )
                    }

                    AppSectionDivider()

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text("Calculated Nose Weight")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text(Formatters.kg(summary.estimatedNoseWeightKg))
                            .font(.largeTitle.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(summary.isOverTowBallLimit ? AppColors.red : Color.accentColor)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppScreenMetrics.cardInteriorPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))

                let carLimitOverridesMin = config.carMaxTowBallKg > 0 && config.carMaxTowBallKg < summary.towBallMinKg
                let carLimitOverridesMax = config.carMaxTowBallKg > 0 && config.carMaxTowBallKg < summary.towBallMaxKg

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMin ? "Car Limit" : "Min (5%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSupporting)
                        Text(Formatters.kg(carLimitOverridesMin ? config.carMaxTowBallKg : summary.towBallMinKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMin ? AppColors.red : Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color(.separator).opacity(0.45))
                        .frame(width: 1)
                        .padding(.vertical, AppScreenMetrics.tinySpacing)

                    VStack(alignment: .trailing, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMax ? "Car Limit" : "Max (7%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSupporting)
                        Text(Formatters.kg(carLimitOverridesMax ? config.carMaxTowBallKg : summary.towBallMaxKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMax ? AppColors.red : Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, AppScreenMetrics.tinySpacing)

                Text("Car Max Tow Ball: \(stripKgSuffix(Formatters.kg(config.carMaxTowBallKg))) kg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, AppScreenMetrics.fieldSpacing)
                    .padding(.horizontal, AppScreenMetrics.controlSpacing)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
            }
        }
    }

    private func mtplmProgressBar(fill: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(AppColors.green)
                    .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
            }
        }
        .frame(height: 8)
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
            .padding(AppScreenMetrics.cardInteriorPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
