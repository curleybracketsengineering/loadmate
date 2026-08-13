import SwiftUI

struct VehicleLookupReviewItem: Identifiable {
    let id = UUID()
    let result: VehicleLookupResult
}

struct VehicleLookupReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let result: VehicleLookupResult
    let applySelection: (_ applyMake: Bool, _ applyModel: Bool) -> Void

    @State private var applyMake = true
    @State private var applyModel = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "text.magnifyingglass",
                        title: "Review vehicle lookup",
                        subtitle: "Suggested values only. Check against your V5C before saving."
                    )

                    Text(Formatters.checkedAtCaption(result.checkedAt))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)

                    AppWarningBanner(message: "Lyneqo Caravan & Motorhome does not confirm DVLA or MOT records. Always verify make, model, tax and MOT against official documents before relying on them.")

                    AppSettingsSection("Registration", caption: "Stored on this motorhome. MOT and tax are shown as at the lookup time.") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                            detailRow("Registration", result.displayRegistration)
                            detailRow("Make", result.make)
                            detailRow("Model", result.model)
                            detailRow("Colour", result.colour)
                            detailRow("Fuel", result.fuelType)
                            detailRow("Type", result.vehicleType)
                            if let year = result.yearOfManufacture {
                                detailRow("Year of manufacture", String(year))
                            }
                            detailRow("First registered", result.monthOfFirstRegistration)
                        }
                    }

                    AppSettingsSection("MOT & tax", caption: Formatters.checkedAtCaption(result.checkedAt)) {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                            detailRow("MOT status", result.motStatus)
                            detailRow("MOT expiry", formattedDate(result.motExpiryDate))
                            if let days = result.motDaysRemaining {
                                detailRow("MOT days remaining", String(days))
                            }
                            detailRow("Last MOT result", result.lastMotResult)
                            detailRow("Last MOT date", formattedDate(result.lastMotDate))
                            detailRow("Tax status", result.taxStatus)
                            detailRow("Tax due", formattedDate(result.taxDueDate))
                            if let export = result.markedForExport {
                                detailRow("Marked for export", export ? "Yes" : "No")
                            }
                        }
                    }

                    AppSettingsSection(
                        "Copy into Settings",
                        caption: "Make and model update only if selected. First registration year and last MOT are stored for Service & warranty and Maintenance."
                    ) {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            suggestionToggle("Manufacturer", value: result.make, isOn: $applyMake)
                            suggestionToggle("Model", value: result.model, isOn: $applyModel)
                            if let year = result.firstRegistrationYear {
                                detailRow("First registered", String(year))
                            }
                            if let mot = VehicleLookupDisplay.lastMOTCaption(
                                lastMotDate: result.lastMotDate,
                                motExpiryDate: result.motExpiryDate
                            ) {
                                detailRow("Last MOT", mot)
                            }
                        }
                    }

                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        AppPrimaryButton("Apply selected suggestions", systemImage: "checkmark.circle.fill") {
                            applySelection(applyMake, applyModel)
                            dismiss()
                        }
                        AppSecondaryButton("Cancel") { dismiss() }
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Vehicle lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func formattedDate(_ value: Date?) -> String? {
        guard let value else { return nil }
        return Formatters.date(value)
    }

    @ViewBuilder
    private func detailRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func suggestionToggle(_ title: String, value: String?, isOn: Binding<Bool>) -> some View {
        if let value, !value.isEmpty {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color.accentColor)
        }
    }
}
