import SwiftUI

/// Car + caravan hitch illustration with live nose-weight and limit overlays.
struct CaravanHitchHeroView: View {
    let profile: VehicleProfile
    let summary: WeightSummary
    var maxHeight: CGFloat = 220
    var showsSideLimitLabels: Bool = true

    /// Layout was tuned against the pad hero height; phone scales offsets from this.
    private static let referenceHeight: CGFloat = 338
    /// Vertical centre of the nose-weight box in the hero (0 = top).
    private static let noseWeightCenterYFraction: CGFloat = 0.20
    private static let noseWeightCenterXOffset: CGFloat = -15
    private static let noseWeightCenterYOffset: CGFloat = 55
    /// Side limit labels sit under the tow ball (car) and hitch (caravan).
    private static let carTowBallLimitCenterXFraction: CGFloat = 0.37
    private static let caravanHitchLimitCenterXFraction: CGFloat = 0.54
    private static let sideLimitCenterYFraction: CGFloat = 0.82

    private var towBallLimitKg: Double { profile.effectiveMaxTowBallKg }
    private var layoutScale: CGFloat { maxHeight / Self.referenceHeight }

    var body: some View {
        ZStack {
            Image("CaravanSummary")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: maxHeight)
                .accessibilityHidden(true)

            GeometryReader { geo in
                noseWeightOverlay
                    .position(
                        x: geo.size.width * 0.5 + Self.noseWeightCenterXOffset * layoutScale,
                        y: geo.size.height * Self.noseWeightCenterYFraction + Self.noseWeightCenterYOffset * layoutScale
                    )

                if showsSideLimitLabels, profile.carMaxTowBallKg > 0 {
                    CaravanHitchSideLimitLabel(
                        text: Self.displayKg(profile.carMaxTowBallKg),
                        accessibilityLabel: "Car tow ball maximum \(Self.displayKg(profile.carMaxTowBallKg))"
                    )
                    .position(
                        x: geo.size.width * Self.carTowBallLimitCenterXFraction,
                        y: geo.size.height * Self.sideLimitCenterYFraction
                    )
                }

                if showsSideLimitLabels, profile.caravanMaxNoseKg > 0 {
                    CaravanHitchSideLimitLabel(
                        text: Self.displayKg(profile.caravanMaxNoseKg),
                        accessibilityLabel: "Caravan hitch maximum \(Self.displayKg(profile.caravanMaxNoseKg))",
                        offsetLeftByOwnWidth: true
                    )
                    .position(
                        x: geo.size.width * Self.caravanHitchLimitCenterXFraction,
                        y: geo.size.height * Self.sideLimitCenterYFraction
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var noseWeightOverlay: some View {
        let limit = towBallLimitKg
        let value = summary.estimatedNoseWeightKg
        let spare = limit > 0 ? limit - value : 0
        let isOver = summary.isOverTowBallLimit || summary.isTowVehicleUnsuitable
        let accent = isOver ? AppColors.red : AppColors.green
        let valueFont: Font = layoutScale < 0.75 ? .title2.weight(.bold) : .title.weight(.bold)

        return Text(Self.displayKg(value))
            .font(valueFont)
            .fontDesign(.rounded)
            .foregroundStyle(accent)
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppScreenMetrics.fieldSpacing)
            .padding(.vertical, AppScreenMetrics.controlSpacing)
            .background(LyneqoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Towbar nose weight \(Self.displayKg(value)). \(noseOverlayFooter(limit: limit, spare: spare, isOver: isOver))"
            )
    }

    private func noseOverlayFooter(limit: Double, spare: Double, isOver: Bool) -> String {
        if summary.isTowVehicleUnsuitable { return "Tow vehicle not suitable" }
        if isOver, limit > 0 { return "\(Self.displayKg(abs(spare))) over limit" }
        if limit > 0, spare >= 0 { return "\(Self.displayKg(spare)) remaining" }
        return "Enter tow ball limit in Settings"
    }

    private static func displayKgNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private static func displayKg(_ value: Double) -> String {
        "\(displayKgNumber(value)) kg"
    }
}

// MARK: - Side limit label

struct CaravanHitchSideLimitLabel: View {
    let text: String
    let accessibilityLabel: String
    var offsetLeftByOwnWidth: Bool = false

    @State private var labelWidth: CGFloat = 0

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(AppColors.green)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { labelWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newWidth in
                            labelWidth = newWidth
                        }
                }
            )
            .offset(x: offsetLeftByOwnWidth ? -labelWidth : 0)
            .accessibilityLabel(accessibilityLabel)
    }
}
