import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query private var configs: [SetupConfig]
    @Query private var loadedItems: [LoadedItem]
    @StateObject private var viewModel = SummaryViewModel()

    private var refreshToken: String {
        let configSignature = configs.first.map {
            "\($0.baseWeightKg)-\($0.weighbridgeWeightKg)-\($0.mtplmKg)-\($0.caravanMaxNoseKg)-\($0.carMaxTowBallKg)-\($0.noseWeightBasePercent)-\($0.factorFrontLocker)-\($0.factorFront)-\($0.factorMiddle)-\($0.factorRear)-\($0.factorBikeRack)"
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
                            statusBanner(summary: summary, config: config)

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
            .toolbar(.hidden, for: .navigationBar)
            .task(id: refreshToken) {
                viewModel.refresh(config: configs.first, loadedItems: loadedItems)
            }
        }
    }

    private enum StatusBannerKind {
        case safe
        case overMTPLM(reduceLoadByKg: Double)
        case towBallLimitExceeded(reduceNoseByKg: Double)
        case noseBelowRecommended(increaseNoseByKg: Double)
        case noseAboveRecommended(reduceNoseByKg: Double)
    }

    private func resolveStatusBanner(summary: WeightSummary, config: SetupConfig) -> StatusBannerKind {
        if summary.isOverallSafe { return .safe }
        if summary.isOverMTPLM {
            let overBy = max(0, summary.totalWeightKg - config.mtplmKg)
            return .overMTPLM(reduceLoadByKg: overBy)
        }
        if summary.isOverTowBallLimit {
            let reduce = max(0, summary.estimatedNoseWeightKg - config.effectiveMaxTowBallKg)
            return .towBallLimitExceeded(reduceNoseByKg: reduce)
        }
        if summary.isNoseBelowRecommended {
            let add = max(0, summary.towBallMinKg - summary.estimatedNoseWeightKg)
            return .noseBelowRecommended(increaseNoseByKg: add)
        }
        if summary.isNoseAboveRecommended {
            let reduce = max(0, summary.estimatedNoseWeightKg - summary.towBallMaxKg)
            return .noseAboveRecommended(reduceNoseByKg: reduce)
        }
        return .safe
    }

    @ViewBuilder
    private func statusBanner(summary: WeightSummary, config: SetupConfig) -> some View {
        let kind = resolveStatusBanner(summary: summary, config: config)

        switch kind {
        case .safe:
            Text("SAFE")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.white)
                .tracking(1.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppScreenMetrics.fieldSpacing)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
                .accessibilityLabel("Status: safe")

        case .overMTPLM(let reduceLoadByKg):
            actionableWarningBanner(
                title: "Caravan weight limit exceeded",
                lines: [
                    "Reduce load by \(kgAmountPhrase(reduceLoadByKg))",
                    "Remove items or lighten the caravan"
                ],
                background: AppColors.red,
                accessibilitySummary: "Caravan weight limit exceeded. Reduce load by \(kgAmountPhrase(reduceLoadByKg))."
            )

        case .towBallLimitExceeded(let reduceNoseByKg):
            actionableWarningBanner(
                title: "Tow ball limit exceeded",
                lines: [
                    "Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg))",
                    "Move items rearward"
                ],
                background: AppColors.red,
                accessibilitySummary: "Tow ball limit exceeded. Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg)). Move items rearward."
            )

        case .noseBelowRecommended(let increaseNoseByKg):
            actionableWarningBanner(
                title: "Nose weight below recommended range",
                lines: [
                    "Increase nose weight by \(kgAmountPhrase(increaseNoseByKg))",
                    "Move heavier items forward"
                ],
                background: AppColors.orange,
                accessibilitySummary: "Nose weight below recommended range. Increase nose weight by \(kgAmountPhrase(increaseNoseByKg)). Move heavier items forward."
            )

        case .noseAboveRecommended(let reduceNoseByKg):
            actionableWarningBanner(
                title: "Nose weight above recommended range",
                lines: [
                    "Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg))",
                    "Move items rearward"
                ],
                background: AppColors.orange,
                accessibilitySummary: "Nose weight above recommended range. Reduce nose weight by \(kgAmountPhrase(reduceNoseByKg)). Move items rearward."
            )
        }
    }

    /// Spoken/written amount like "4.3 kg" (no double "kg").
    private func kgAmountPhrase(_ kg: Double) -> String {
        stripKgSuffix(Formatters.kg(kg)) + " kg"
    }

    private func actionableWarningBanner(
        title: String,
        lines: [String],
        background: Color,
        accessibilitySummary: String
    ) -> some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppScreenMetrics.fieldSpacing + 2)
        .padding(.horizontal, AppScreenMetrics.controlSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func currentWeightCard(summary: WeightSummary, config: SetupConfig) -> some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Current Weight")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(Formatters.kg(summary.totalWeightKg))
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(summary.isOverMTPLM ? AppColors.red : Color.accentColor)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                mtplmProgressBar(
                    fill: CGFloat(summary.mtplmFillFraction(config: config)),
                    isOverLimit: summary.isOverMTPLM
                )

                HStack {
                    Text("MTPLM: \(stripKgSuffix(Formatters.kg(config.mtplmKg))) kg")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text("Available: \(stripKgSuffix(Formatters.kg(summary.availableWeightKg))) kg")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(summary.availableWeightKg < 0 ? AppColors.red : Color.secondary)
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

                let zoneBounds = summary.noseGaugeZoneBounds(config: config)

                NoseWeightSafeZoneGauge(
                    zoneLowKg: zoneBounds.low,
                    zoneHighKg: zoneBounds.high,
                    carMaxTowBallKg: config.effectiveMaxTowBallKg,
                    estimatedNoseKg: summary.estimatedNoseWeightKg
                )

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    HStack {
                        Text(baseNosePercentLabel(config: config))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text(Formatters.kg(summary.baseNosePercentKg))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                    }

                    HStack {
                        Text("Location Impact")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text(signedKg(summary.locationImpactKg))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }

                    AppSectionDivider()

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text("Calculated Nose Weight")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.secondary)
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

                HStack(spacing: 0) {
                    let effectiveLimit = config.effectiveMaxTowBallKg
                    let carLimitOverridesMin = effectiveLimit > 0 && effectiveLimit < summary.towBallMinKg
                    let carLimitOverridesMax = effectiveLimit > 0 && effectiveLimit < summary.towBallMaxKg

                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMin ? "Car Limit" : "Min (5%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                        Text(Formatters.kg(carLimitOverridesMin ? effectiveLimit : summary.towBallMinKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMin ? Color.accentColor : Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color(.separator).opacity(0.45))
                        .frame(width: 1)
                        .padding(.vertical, AppScreenMetrics.tinySpacing)

                    VStack(alignment: .trailing, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMax ? "Car Limit" : "Max (7%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                        Text(Formatters.kg(carLimitOverridesMax ? effectiveLimit : summary.towBallMaxKg))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(carLimitOverridesMax ? Color.accentColor : Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, AppScreenMetrics.tinySpacing)
            }
        }
    }

    private func mtplmProgressBar(fill: CGFloat, isOverLimit: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(isOverLimit ? AppColors.red : Color.accentColor)
                    .frame(width: max(geo.size.width * fill, fill > 0 ? 4 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Progress toward MTPLM")
        .accessibilityValue("\(Int(fill * 100)) percent")
    }

    private func baseNosePercentLabel(config: SetupConfig) -> String {
        let percent = config.noseWeightBasePercent > 0 ? config.noseWeightBasePercent : 6.0
        if percent.truncatingRemainder(dividingBy: 1) == 0 {
            return "Base (\(Int(percent))%)"
        }
        return String(format: "Base (%.1f%%)", percent)
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
