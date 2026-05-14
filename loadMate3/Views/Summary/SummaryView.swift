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
            let reduce = max(0, summary.estimatedNoseWeightKg - config.carMaxTowBallKg)
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

                let carLimitOverridesMin = config.carMaxTowBallKg > 0 && config.carMaxTowBallKg < summary.towBallMinKg
                let carLimitOverridesMax = config.carMaxTowBallKg > 0 && config.carMaxTowBallKg < summary.towBallMaxKg
                let zoneLow = carLimitOverridesMin ? config.carMaxTowBallKg : summary.towBallMinKg
                let zoneHigh = carLimitOverridesMax ? config.carMaxTowBallKg : summary.towBallMaxKg

                NoseWeightSafeZoneGauge(
                    zoneLowKg: zoneLow,
                    zoneHighKg: zoneHigh,
                    carMaxTowBallKg: config.carMaxTowBallKg,
                    estimatedNoseKg: summary.estimatedNoseWeightKg
                )

                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    HStack {
                        Text("Base (6%)")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text(Formatters.kg(summary.baseNoseSixPercentKg))
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
                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        Text(carLimitOverridesMin ? "Car Limit" : "Min (5%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                        Text(Formatters.kg(carLimitOverridesMin ? config.carMaxTowBallKg : summary.towBallMinKg))
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
                        Text(Formatters.kg(carLimitOverridesMax ? config.carMaxTowBallKg : summary.towBallMaxKg))
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

// MARK: - Nose weight safe zone

/// Horizontal scale: green = ideal band, amber = caution outside band (but not over car limit), red = over limit.
private struct NoseWeightSafeZoneGauge: View {
    let zoneLowKg: Double
    let zoneHighKg: Double
    let carMaxTowBallKg: Double
    let estimatedNoseKg: Double

    private static let amberFill = Color(red: 0.97, green: 0.73, blue: 0.12)
    private static let barHeight: CGFloat = 12
    private static let markerHeight: CGFloat = 20
    /// Matches gap from bar bottom to tick label centres (`tickLabel` `y` offset).
    private static let tickBarGap: CGFloat = 26
    /// Fixed height for the “Max tow” stack above the bar (text + triangle).
    private static let carMaxPointerHeight: CGFloat = 48

    private static let legendScale: CGFloat = 1.1
    private static let legendDotDiameter: CGFloat = 7 * legendScale
    private static let legendTextSize: CGFloat = 11 * legendScale
    private static let legendTriangleSize: CGFloat = 8 * legendScale

    /// Y-offset of the coloured bar: room above for car max pointer + same gap as tick labels.
    private var barTop: CGFloat {
        carMaxTowBallKg > 0 ? Self.tickBarGap + Self.carMaxPointerHeight : 2
    }

    private var idealMidKg: Double { (zoneLowKg + zoneHighKg) / 2 }

    private var axisMin: Double {
        let candidates = [zoneLowKg, zoneHighKg, estimatedNoseKg, carMaxTowBallKg > 0 ? carMaxTowBallKg : zoneHighKg]
        let lo = candidates.min() ?? 0
        let pad = max((zoneHighKg - zoneLowKg) * 0.12, 2)
        return max(0, lo - pad)
    }

    private var axisMax: Double {
        var hi = max(zoneHighKg, estimatedNoseKg)
        if carMaxTowBallKg > 0 { hi = max(hi, carMaxTowBallKg) }
        let pad = max((zoneHighKg - zoneLowKg) * 0.12, 2)
        return hi + pad
    }

    private var axisSpan: Double { max(axisMax - axisMin, 1) }

    private func xFraction(for kg: Double) -> CGFloat {
        CGFloat((kg - axisMin) / axisSpan)
    }

    private func clampedXFraction(_ kg: Double) -> CGFloat {
        min(max(xFraction(for: kg), 0), 1)
    }

    private var segmentBoundaries: [Double] {
        var values: [Double] = [axisMin, axisMax, zoneLowKg, zoneHighKg]
        if carMaxTowBallKg > 0 {
            values.append(carMaxTowBallKg)
        }
        let sorted = values.sorted()
        var deduped: [Double] = []
        for v in sorted {
            if let last = deduped.last, abs(v - last) < 1e-6 {
                continue
            }
            deduped.append(v)
        }
        return deduped
    }

    private func zoneColor(forKilograms kg: Double) -> Color {
        if kg < zoneLowKg { return Self.amberFill }
        if kg <= zoneHighKg { return AppColors.green.opacity(0.92) }
        if carMaxTowBallKg > 0, kg <= carMaxTowBallKg { return Self.amberFill }
        return AppColors.red
    }

    private var segments: [(start: Double, end: Double, color: Color)] {
        let pts = segmentBoundaries
        guard pts.count >= 2 else { return [] }
        var result: [(start: Double, end: Double, color: Color)] = []
        for i in 0..<(pts.count - 1) {
            let s = pts[i]
            let t = pts[i + 1]
            guard t > s + 0.0001 else { continue }
            let mid = (s + t) / 2
            let color = zoneColor(forKilograms: mid)
            result.append((start: s, end: t, color: color))
        }
        return result
    }

    private var accessibilitySummary: String {
        let est = kgAmountGauge(estimatedNoseKg)
        if estimatedNoseKg < zoneLowKg {
            return "Estimated nose weight \(est), below ideal range starting at \(kgAmountGauge(zoneLowKg))."
        }
        if estimatedNoseKg > zoneHighKg, carMaxTowBallKg > 0, estimatedNoseKg <= carMaxTowBallKg {
            return "Estimated nose weight \(est), above ideal range but within car tow ball limit \(kgAmountGauge(carMaxTowBallKg))."
        }
        if carMaxTowBallKg > 0, estimatedNoseKg > carMaxTowBallKg {
            return "Estimated nose weight \(est), over car tow ball limit \(kgAmountGauge(carMaxTowBallKg))."
        }
        if estimatedNoseKg > zoneHighKg {
            return "Estimated nose weight \(est), above ideal range up to \(kgAmountGauge(zoneHighKg))."
        }
        if carMaxTowBallKg > 0 {
            return "Estimated nose weight \(est), within ideal range \(kgAmountGauge(zoneLowKg)) to \(kgAmountGauge(zoneHighKg)). Car maximum tow ball \(kgAmountGauge(carMaxTowBallKg))."
        }
        return "Estimated nose weight \(est), within ideal range \(kgAmountGauge(zoneLowKg)) to \(kgAmountGauge(zoneHighKg))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safe zone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)

            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .topLeading) {
                    if carMaxTowBallKg > 0 {
                        carMaxTowBallPointer()
                            .position(
                                x: clampedCenterX(forKg: carMaxTowBallKg, width: width),
                                y: barTop - Self.tickBarGap - Self.carMaxPointerHeight / 2
                            )
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: 0) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                            let w = max(width * CGFloat((seg.end - seg.start) / axisSpan), 0)
                            Rectangle()
                                .fill(seg.color)
                                .frame(width: w)
                        }
                    }
                    .frame(height: Self.barHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .offset(x: 0, y: barTop)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.primary)
                        .frame(width: 4, height: Self.markerHeight)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(
                            x: clampedCenterX(forKg: estimatedNoseKg, width: width) - 2,
                            y: barTop + Self.barHeight / 2 - Self.markerHeight / 2
                        )
                        .accessibilityHidden(true)

                    tickLabel(valueKg: zoneLowKg, title: "Low", width: width)
                        .position(x: labelX(forKg: zoneLowKg, width: width), y: barTop + Self.barHeight + Self.tickBarGap)

                    tickLabel(valueKg: idealMidKg, title: "Ideal", width: width)
                        .position(x: labelX(forKg: idealMidKg, width: width), y: barTop + Self.barHeight + Self.tickBarGap)

                    tickLabel(valueKg: zoneHighKg, title: "Max", width: width)
                        .position(x: labelX(forKg: zoneHighKg, width: width), y: barTop + Self.barHeight + Self.tickBarGap)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: barTop + Self.barHeight + 52)

            HStack(spacing: AppScreenMetrics.smallSpacing * Self.legendScale) {
                legendDot(AppColors.green.opacity(0.92))
                Text("Ideal")
                    .foregroundStyle(Color.secondary)
                legendDot(Self.amberFill)
                Text("Caution")
                    .foregroundStyle(Color.secondary)
                legendDot(AppColors.red)
                Text("Over limit")
                    .foregroundStyle(Color.secondary)
                if carMaxTowBallKg > 0 {
                    Text("·")
                        .foregroundStyle(Color.secondary.opacity(0.55))
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: Self.legendTriangleSize, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Car max")
                        .foregroundStyle(Color.secondary)
                }
            }
            .font(.system(size: Self.legendTextSize, weight: .regular))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nose weight safe zone")
        .accessibilityValue(accessibilitySummary)
    }

    private func labelX(forKg kg: Double, width: CGFloat) -> CGFloat {
        clampedCenterX(forKg: kg, width: width)
    }

    private func clampedCenterX(forKg kg: Double, width: CGFloat) -> CGFloat {
        let raw = width * clampedXFraction(kg)
        return min(max(raw, 26), width - 26)
    }

    private func carMaxTowBallPointer() -> some View {
        VStack(spacing: 2) {
            Text("Max tow")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.secondary)
            Text(stripKgGauge(Formatters.kg(carMaxTowBallKg)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Spacer(minLength: 0)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 76, height: Self.carMaxPointerHeight, alignment: .top)
    }

    private func tickLabel(valueKg: Double, title: String, width: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(stripKgGauge(Formatters.kg(valueKg)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(width: min(width * 0.34, 120))
    }

    private func legendDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: Self.legendDotDiameter, height: Self.legendDotDiameter)
    }

    private func stripKgGauge(_ s: String) -> String {
        s.replacingOccurrences(of: " kg", with: "").trimmingCharacters(in: .whitespaces) + " kg"
    }

    private func kgAmountGauge(_ kg: Double) -> String {
        stripKgGauge(Formatters.kg(kg))
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
