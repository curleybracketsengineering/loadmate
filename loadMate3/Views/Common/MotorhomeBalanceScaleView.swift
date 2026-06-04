import SwiftUI

/// Horizontal load-balance scale: front-heavy (leading) ↔ balanced (centre) ↔ rear-heavy (trailing).
struct MotorhomeBalanceScaleView: View {
    let isWarning: Bool
    let indicatorFraction: CGFloat
    /// Shown centred above the balance marker (e.g. location impact on nose weight).
    var markerLabel: String?

    private static let barHeight: CGFloat = 10
    private static let markerWidth: CGFloat = 4
    private static let markerHeight: CGFloat = 22
    private static let markerLabelHeight: CGFloat = 18
    private static let markerLabelGap: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            GeometryReader { geo in
                let width = geo.size.width
                let markerX = markerCenterX(width: width)
                let chartTop = markerLabel == nil ? CGFloat(0) : Self.markerLabelHeight + Self.markerLabelGap

                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            AppColors.orange.opacity(0.88),
                            AppColors.green.opacity(0.9),
                            AppColors.orange.opacity(0.88),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: Self.barHeight)
                    .clipShape(Capsule())
                    .offset(y: chartTop)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(isWarning ? AppColors.orange : Color.primary)
                        .frame(width: Self.markerWidth, height: Self.markerHeight)
                        .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                        .position(x: markerX, y: chartTop + Self.barHeight / 2)
                        .accessibilityHidden(true)

                    if let markerLabel {
                        Text(markerLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isWarning ? AppColors.orange : Color.primary)
                            .fixedSize()
                            .position(x: markerX, y: Self.markerLabelHeight / 2)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: chartHeight)

            HStack {
                Text("Front-heavy")
                    .foregroundStyle(AppColors.orange)
                Spacer(minLength: AppScreenMetrics.controlSpacing)
                Text("Balanced")
                    .foregroundStyle(AppColors.green)
                Spacer(minLength: AppScreenMetrics.controlSpacing)
                Text("Rear-heavy")
                    .foregroundStyle(AppColors.orange)
            }
            .font(.caption2.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var chartHeight: CGFloat {
        guard markerLabel != nil else { return Self.markerHeight }
        return Self.markerLabelHeight + Self.markerLabelGap + Self.markerHeight
    }

    private func markerCenterX(width: CGFloat) -> CGFloat {
        let half = Self.markerWidth / 2
        let minX = half
        let maxX = width - half
        let raw = width * min(max(indicatorFraction, 0), 1)
        return min(max(raw, minX), maxX)
    }

    private var accessibilitySummary: String {
        let position: String
        if indicatorFraction < 0.34 {
            position = "toward front-heavy"
        } else if indicatorFraction > 0.66 {
            position = "toward rear-heavy"
        } else {
            position = "near balanced"
        }
        if let markerLabel {
            return "Balance scale. Location impact \(markerLabel). Indicator \(position)."
        }
        return "Balance scale. Indicator \(position)."
    }
}
