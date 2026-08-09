import SwiftUI

struct TyreCopyFromSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TyreSupport.pressureUnitAppStorageKey) private var pressureUnitRaw = PressureUnit.psi.rawValue

    let sources: [TyreRecord]
    let applyDetails: (_ manufacturer: String?, _ modelName: String?, _ tyreSize: String?, _ loadIndex: String?, _ speedRating: String?, _ dateCode: String?, _ recommendedPressurePSI: Double?) -> Void

    @State private var selectedSourceID: UUID?
    @State private var applyManufacturer = true
    @State private var applyModelName = true
    @State private var applyTyreSize = true
    @State private var applyLoadIndex = true
    @State private var applySpeedRating = true
    @State private var applyDateCode = true
    @State private var applyRecommendedPressure = true

    private var pressureUnit: PressureUnit {
        PressureUnit(rawValue: pressureUnitRaw) ?? .psi
    }

    private var selectedSource: TyreRecord? {
        sources.first(where: { $0.id == selectedSourceID })
    }

    private var selectedDetails: TyreCopyableDetails? {
        selectedSource.map(TyreCopyableDetails.from)
    }

    private var canApply: Bool {
        guard let details = selectedDetails, details.hasAnyValue else { return false }
        return selectedFieldCount(from: details) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "rectangle.on.rectangle",
                        title: "Copy from another tyre",
                        subtitle: "Copy shared specification details onto this tyre. Pressure readings, condition and photos stay with each individual tyre."
                    )

                    AppSettingsSection("Source tyre") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                            ForEach(sources) { source in
                                sourceRow(source)
                            }
                        }
                    }

                    if let details = selectedDetails {
                        AppSettingsSection(
                            "Fields to copy",
                            caption: "Choose which values to copy into this tyre. Copied fields are saved straight away."
                        ) {
                            if details.hasAnyValue {
                                VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                                    fieldToggle("Manufacturer", value: nonEmpty(details.manufacturer), isOn: $applyManufacturer)
                                    fieldToggle("Model", value: nonEmpty(details.modelName), isOn: $applyModelName)
                                    fieldToggle("Tyre size", value: nonEmpty(details.tyreSize), isOn: $applyTyreSize)
                                    fieldToggle("Load index", value: nonEmpty(details.loadIndex), isOn: $applyLoadIndex)
                                    fieldToggle("Speed rating", value: nonEmpty(details.speedRating), isOn: $applySpeedRating)
                                    fieldToggle(
                                        "Manufacture date code",
                                        value: nonEmpty(details.dateCode),
                                        isOn: $applyDateCode
                                    )
                                    fieldToggle(
                                        "Recommended cold pressure",
                                        value: details.recommendedPressurePSI.map { Formatters.pressure($0, unit: pressureUnit) },
                                        isOn: $applyRecommendedPressure
                                    )
                                }
                            } else {
                                Text("This tyre has no shared details to copy yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSupporting)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        AppPrimaryButton("Copy selected fields", systemImage: "checkmark.circle.fill") {
                            applySelectedFields()
                            dismiss()
                        }
                        .disabled(!canApply)
                        AppSecondaryButton("Cancel") { dismiss() }
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Copy details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if selectedSourceID == nil {
                    selectedSourceID = sources.first(where: { TyreCopyableDetails.from($0).hasAnyValue })?.id
                        ?? sources.first?.id
                }
            }
        }
    }

    private func sourceRow(_ source: TyreRecord) -> some View {
        let details = TyreCopyableDetails.from(source)
        let isSelected = selectedSourceID == source.id
        return Button {
            selectedSourceID = source.id
            applyManufacturer = true
            applyModelName = true
            applyTyreSize = true
            applyLoadIndex = true
            applySpeedRating = true
            applyDateCode = true
            applyRecommendedPressure = true
        } label: {
            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(details.summaryLine)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppScreenMetrics.smallSpacing)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.displayName), \(details.summaryLine)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func fieldToggle(_ title: String, value: String?, isOn: Binding<Bool>) -> some View {
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

    private func applySelectedFields() {
        guard let details = selectedDetails else { return }
        applyDetails(
            applyManufacturer ? nonEmpty(details.manufacturer) : nil,
            applyModelName ? nonEmpty(details.modelName) : nil,
            applyTyreSize ? nonEmpty(details.tyreSize) : nil,
            applyLoadIndex ? nonEmpty(details.loadIndex) : nil,
            applySpeedRating ? nonEmpty(details.speedRating) : nil,
            applyDateCode ? nonEmpty(details.dateCode) : nil,
            applyRecommendedPressure ? details.recommendedPressurePSI : nil
        )
    }

    private func selectedFieldCount(from details: TyreCopyableDetails) -> Int {
        var count = 0
        if applyManufacturer, nonEmpty(details.manufacturer) != nil { count += 1 }
        if applyModelName, nonEmpty(details.modelName) != nil { count += 1 }
        if applyTyreSize, nonEmpty(details.tyreSize) != nil { count += 1 }
        if applyLoadIndex, nonEmpty(details.loadIndex) != nil { count += 1 }
        if applySpeedRating, nonEmpty(details.speedRating) != nil { count += 1 }
        if applyDateCode, nonEmpty(details.dateCode) != nil { count += 1 }
        if applyRecommendedPressure, details.recommendedPressurePSI != nil { count += 1 }
        return count
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
