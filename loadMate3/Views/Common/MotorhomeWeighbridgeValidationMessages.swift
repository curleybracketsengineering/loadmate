import SwiftUI

/// Inline warnings when motorhome weighbridge gross and axle weights disagree.
struct MotorhomeWeighbridgeValidationMessages: View {
    let profile: VehicleProfile

    var body: some View {
        let messages = profile.motorhomeWeighbridgeValidation.allMessages
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.orange)
                            .accessibilityHidden(true)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(AppScreenMetrics.cardInteriorPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}
