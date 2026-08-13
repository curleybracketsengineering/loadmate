import SwiftUI
import UIKit

struct CRiSVINChipReviewItem: Identifiable {
    let id = UUID()
    let suggestions: CRiSVINChipSuggestions
    let image: UIImage
}

struct CRiSVINChipReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: CRiSVINChipReviewItem
    let apply: (_ vin: String, _ savePhoto: Bool, _ image: UIImage) -> Void

    @State private var applyVIN = true
    @State private var savePhotoToDocuments = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "qrcode.viewfinder",
                        title: "Review CRiS VIN Chip",
                        subtitle: "Suggested VIN only. Check against the sticker or registration document before saving."
                    )

                    AppWarningBanner(message: "Lyneqo Caravan & Motorhome does not confirm CRiS readings. Always verify the VIN against your CRiS document or VIN Chip markings before relying on it.")

                    Image(uiImage: item.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
                        .accessibilityLabel("CRiS VIN Chip photo")

                    AppSettingsSection("Suggested fields", caption: "Choose what to save into Settings and Documents.") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            if let vin = item.suggestions.vinChassisNumber, !vin.isEmpty {
                                Toggle(isOn: $applyVIN) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("VIN / chassis")
                                            .font(.subheadline.weight(.semibold))
                                        Text(vin)
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textSupporting)
                                            .fixedSize(horizontal: false, vertical: true)
                                        if let source = item.suggestions.source {
                                            Text(sourceCaption(source))
                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textSupporting)
                                        }
                                    }
                                }
                                .tint(Color.accentColor)
                            }

                            Toggle(isOn: $savePhotoToDocuments) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Save photo to Documents")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Stores the VIN Chip image under VIN / Chassis Information for this vehicle.")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSupporting)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .tint(Color.accentColor)
                        }
                    }

                    if !item.suggestions.confidenceNotes.isEmpty {
                        AppSettingsSection("Notes") {
                            VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                                ForEach(item.suggestions.confidenceNotes, id: \.self) { note in
                                    Text(note)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        AppPrimaryButton("Apply", systemImage: "checkmark.circle.fill") {
                            let vin = applyVIN ? (item.suggestions.vinChassisNumber ?? "") : ""
                            apply(vin, savePhotoToDocuments, item.image)
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
            .navigationTitle("CRiS VIN Chip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var canApply: Bool {
        let hasVIN = applyVIN && !(item.suggestions.vinChassisNumber ?? "").isEmpty
        return hasVIN || savePhotoToDocuments
    }

    private func sourceCaption(_ source: CRiSVINChipSuggestions.Source) -> String {
        switch source {
        case .qrCode: return "From QR code"
        case .ocrText: return "From printed text"
        }
    }
}
