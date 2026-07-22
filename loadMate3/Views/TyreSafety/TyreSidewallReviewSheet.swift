import SwiftUI

struct TyreSidewallReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestions: TyreSidewallSuggestions
    let applySuggestions: (_ manufacturer: String?, _ modelName: String?, _ tyreSize: String?, _ loadIndex: String?, _ speedRating: String?, _ dateCode: String?) -> Void

    @State private var applyManufacturer = true
    @State private var applyModelName = true
    @State private var applyTyreSize = true
    @State private var applyLoadIndex = true
    @State private var applySpeedRating = true
    @State private var applyDateCode = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "text.viewfinder",
                        title: "Review sidewall suggestions",
                        subtitle: "Suggested values only. Check against the tyre marking before saving."
                    )

                    AppWarningBanner(message: "Lyneqo Caravan & Motorhome does not confirm that a tyre is safe, road legal, certified, or suitable for continued use. Review every suggested field before applying it.")

                    AppSettingsSection("Suggested fields", caption: "Choose which values to copy into the tyre record.") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            suggestionToggle("Manufacturer", value: suggestions.manufacturer, isOn: $applyManufacturer)
                            suggestionToggle("Model", value: suggestions.modelName, isOn: $applyModelName)
                            suggestionToggle("Tyre size", value: suggestions.tyreSize, isOn: $applyTyreSize)
                            suggestionToggle("Load index", value: suggestions.loadIndex, isOn: $applyLoadIndex)
                            suggestionToggle("Speed rating", value: suggestions.speedRating, isOn: $applySpeedRating)
                            suggestionToggle("Manufacture date code", value: suggestions.dateCode, isOn: $applyDateCode)
                        }
                    }

                    if !suggestions.confidenceNotes.isEmpty {
                        AppSettingsSection("Notes") {
                            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                                ForEach(suggestions.confidenceNotes, id: \.self) { note in
                                    Text(note)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        AppPrimaryButton("Apply selected suggestions", systemImage: "checkmark.circle.fill") {
                            applySuggestions(
                                applyManufacturer ? suggestions.manufacturer : nil,
                                applyModelName ? suggestions.modelName : nil,
                                applyTyreSize ? suggestions.tyreSize : nil,
                                applyLoadIndex ? suggestions.loadIndex : nil,
                                applySpeedRating ? suggestions.speedRating : nil,
                                applyDateCode ? suggestions.dateCode : nil
                            )
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
            .navigationTitle("Sidewall OCR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
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
