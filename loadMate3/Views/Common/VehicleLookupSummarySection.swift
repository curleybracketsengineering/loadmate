import SwiftUI

/// Make, model, first registration year, and last MOT from vehicle lookup.
struct VehicleLookupSummarySection: View {
    let profile: VehicleProfile

    var body: some View {
        if VehicleLookupDisplay.hasSummary(for: profile) {
            AppSettingsSection("Vehicle", caption: caption) {
                VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                    if let identity = VehicleLookupDisplay.identityLine(for: profile) {
                        Text(identity)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let year = profile.firstRegistrationYear {
                        labeledRow("First registered", String(year))
                    }
                    if let mot = VehicleLookupDisplay.lastMOTCaption(for: profile) {
                        if mot == VehicleLookupDisplay.motDueCaption {
                            Text(mot)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LyneqoTheme.Status.warning)
                        } else {
                            labeledRow("Last MOT", mot)
                        }
                    }
                }
            }
        }
    }

    private var caption: String? {
        let hasLookupIdentity = VehicleLookupDisplay.identityLine(for: profile) != nil
            || profile.firstRegistrationYear != nil
            || profile.lastMotDate != nil
            || profile.motExpiryDate != nil
        return hasLookupIdentity ? "From vehicle lookup. Confirm against your V5C and MOT certificate." : nil
    }

    @ViewBuilder
    private func labeledRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
            Text(value)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
