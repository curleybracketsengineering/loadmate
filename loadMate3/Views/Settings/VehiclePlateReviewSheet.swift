import SwiftUI
import UIKit

struct VehiclePlateReviewItem: Identifiable {
    let id = UUID()
    let suggestions: VehiclePlateSuggestions
    let image: UIImage
}

struct VehiclePlateReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TyreSupport.pressureUnitAppStorageKey) private var pressureUnitRaw = PressureUnit.psi.rawValue

    let kind: VehicleKind
    let item: VehiclePlateReviewItem
    let applySuggestions: (VehiclePlateSuggestions) -> Void

    private var suggestions: VehiclePlateSuggestions { item.suggestions }

    @State private var applyManufacturer = true
    @State private var applyModelName = true
    @State private var applyVIN = true
    @State private var applyBodyCell = true
    @State private var applyMTPLM = true
    @State private var applyGTW = true
    @State private var applyMIRO = true
    @State private var applyNose = true
    @State private var applyFrontAxle = true
    @State private var applyRearAxle = true
    @State private var applyTyreSize = true
    @State private var applyTyrePressure = true
    @State private var applySteelTorque = true
    @State private var applyAlloyTorque = true

    private var pressureUnit: PressureUnit {
        PressureUnit(rawValue: pressureUnitRaw) ?? .psi
    }

    private var plateReviewWarningMessage: String {
        switch kind {
        case .caravan:
            return "Lyneqo Caravan & Motorhome does not confirm plate readings. Always verify manufacturer, model, weights, VIN, tyre size, pressure and wheel nut torque against the manufacturer plate before relying on them."
        case .motorhome:
            return "Lyneqo Caravan & Motorhome does not confirm plate readings. Always verify manufacturer, model, weights, VIN, body/cell number, tyre size and pressure against the manufacturer plate before relying on them."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "text.viewfinder",
                        title: "Review plate suggestions",
                        subtitle: "Suggested values only. Check against the physical plate before saving."
                    )

                    AppWarningBanner(message: plateReviewWarningMessage)

                    Image(uiImage: item.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
                        .accessibilityLabel("Manufacturer plate photo")

                    AppSettingsSection("Suggested fields", caption: kind == .caravan
                        ? "Choose which values to copy into Settings and Tyre Safety. Wheel nut torque is stored for Tyre Safety. Applying also keeps this plate photo in Settings."
                        : "Choose which values to copy into Settings and Tyre Safety. Applying also keeps this plate photo in Settings.") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            suggestionToggle("Manufacturer", value: suggestions.manufacturer, isOn: $applyManufacturer)
                            suggestionToggle("Model", value: suggestions.modelName, isOn: $applyModelName)
                            suggestionToggle("VIN / chassis", value: suggestions.vinChassisNumber, isOn: $applyVIN)
                            if kind == .motorhome {
                                suggestionToggle("Body / cell number", value: suggestions.bodyCellNumber, isOn: $applyBodyCell)
                            }
                            suggestionToggle(
                                kind == .caravan ? "MTPLM (kg)" : "MAM (kg)",
                                value: formattedKg(suggestions.mtplmOrMamKg),
                                isOn: $applyMTPLM
                            )
                            if kind == .motorhome {
                                suggestionToggle(
                                    "GTW (kg)",
                                    value: formattedKg(suggestions.gtwKg),
                                    isOn: $applyGTW
                                )
                            }
                            suggestionToggle(
                                kind == .caravan ? "MIRO (kg)" : "MRO (kg)",
                                value: formattedKg(suggestions.miroOrMroKg),
                                isOn: $applyMIRO
                            )
                            if kind == .caravan {
                                suggestionToggle(
                                    "Caravan hitch limit (kg)",
                                    value: formattedKg(suggestions.hitchOrNoseKg),
                                    isOn: $applyNose
                                )
                            }
                            if kind == .motorhome {
                                suggestionToggle(
                                    "Max front axle (kg)",
                                    value: formattedKg(suggestions.maxFrontAxleKg),
                                    isOn: $applyFrontAxle
                                )
                                suggestionToggle(
                                    "Max rear axle (kg)",
                                    value: formattedKg(suggestions.maxRearAxleKg),
                                    isOn: $applyRearAxle
                                )
                            }
                            suggestionToggle("Tyre size", value: suggestions.tyreSize, isOn: $applyTyreSize)
                            suggestionToggle(
                                "Tyre pressure",
                                value: formattedPressure(suggestions.tyrePressurePSI, plateUnit: suggestions.tyrePressureDisplayUnit),
                                isOn: $applyTyrePressure
                            )
                            if kind == .caravan {
                                suggestionToggle(
                                    "Wheel nut torque — steel (Nm)",
                                    value: formattedNm(suggestions.wheelNutTorqueSteelNm),
                                    isOn: $applySteelTorque
                                )
                                suggestionToggle(
                                    "Wheel nut torque — alloy (Nm)",
                                    value: formattedNm(suggestions.wheelNutTorqueAlloyNm),
                                    isOn: $applyAlloyTorque
                                )
                            }
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
                            applySuggestions(selectedSuggestions())
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
            .navigationTitle("Plate OCR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func selectedSuggestions() -> VehiclePlateSuggestions {
        VehiclePlateSuggestions(
            vinChassisNumber: applyVIN ? suggestions.vinChassisNumber : nil,
            manufacturer: applyManufacturer ? suggestions.manufacturer : nil,
            modelName: applyModelName ? suggestions.modelName : nil,
            mtplmOrMamKg: applyMTPLM ? suggestions.mtplmOrMamKg : nil,
            miroOrMroKg: applyMIRO ? suggestions.miroOrMroKg : nil,
            hitchOrNoseKg: applyNose ? suggestions.hitchOrNoseKg : nil,
            maxFrontAxleKg: applyFrontAxle ? suggestions.maxFrontAxleKg : nil,
            maxRearAxleKg: applyRearAxle ? suggestions.maxRearAxleKg : nil,
            gtwKg: kind == .motorhome && applyGTW ? suggestions.gtwKg : nil,
            bodyCellNumber: kind == .motorhome && applyBodyCell ? suggestions.bodyCellNumber : nil,
            tyreSize: applyTyreSize ? suggestions.tyreSize : nil,
            tyrePressurePSI: applyTyrePressure ? suggestions.tyrePressurePSI : nil,
            tyrePressureDisplayUnit: applyTyrePressure ? suggestions.tyrePressureDisplayUnit : nil,
            wheelNutTorqueSteelNm: kind == .caravan && applySteelTorque ? suggestions.wheelNutTorqueSteelNm : nil,
            wheelNutTorqueAlloyNm: kind == .caravan && applyAlloyTorque ? suggestions.wheelNutTorqueAlloyNm : nil,
            confidenceNotes: suggestions.confidenceNotes
        )
    }

    private func formattedKg(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.0f", value)
    }

    private func formattedNm(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.0f", value)
    }

    private func formattedPressure(_ psi: Double?, plateUnit: PressureUnit?) -> String? {
        guard let psi else { return nil }
        let preferred = plateUnit ?? pressureUnit
        let display = TyreSupport.convertPressure(psi, from: .psi, to: preferred)
        return Formatters.plainPressure(display, unit: preferred)
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
