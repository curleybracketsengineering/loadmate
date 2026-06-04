import SwiftUI

/// Horizontal load-balance scale: front-heavy (leading) ↔ balanced (centre) ↔ rear-heavy (trailing).
struct MotorhomeBalanceScaleView: View {
    let title: String
    let isWarning: Bool
    let indicatorFraction: CGFloat

    private static let barHeight: CGFloat = 10
    private static let markerWidth: CGFloat = 4
    private static let markerHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Text("Load balance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)

            GeometryReader { geo in
                let width = geo.size.width
                let markerX = markerCenterX(width: width)

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

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(isWarning ? AppColors.orange : Color.primary)
                        .frame(width: Self.markerWidth, height: Self.markerHeight)
                        .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                        .position(x: markerX, y: Self.barHeight / 2)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: Self.markerHeight)

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

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isWarning ? AppColors.orange : AppColors.green)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
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
        return "Load balance. \(title). Indicator \(position)."
    }
}
