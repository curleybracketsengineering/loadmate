import SwiftUI

/// Wheel marker under a zone box on the motorhome map.
struct MotorhomeAxleWheelIndicator: View {
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            AxleWheelGraphic()
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) axle")
    }
}

private struct AxleWheelGraphic: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(LyneqoTheme.border.opacity(0.55))
                .frame(width: 28, height: 3)

            Circle()
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
                }
                .frame(width: 20, height: 20)

            Circle()
                .fill(Color.secondary.opacity(0.65))
                .frame(width: 5, height: 5)
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}
