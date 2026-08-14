import SwiftUI
import SwiftData

struct DisclaimerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DisclaimerViewModel()

    let appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        Image("LyneqoMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityHidden(true)

                        Text("Lyneqo Caravan & Motorhome")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(LyneqoTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Plan your caravan or motorhome loading with confidence")
                            .font(.caption)
                            .foregroundStyle(LyneqoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, AppScreenMetrics.smallSpacing)

                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        paragraph(
                            "Lyneqo Caravan & Motorhome helps you plan what goes where before you travel, so you can stay within your limits."
                        )
                        paragraph(
                            "For caravans, it estimates packed weight, nose weight impact, and checks against your caravan and tow vehicle limits."
                        )
                        paragraph(
                            "For motorhomes, it estimates how loading affects front and rear axle weights, and checks your MAM, axle, garage, and tow bar limits."
                        )
                        paragraph(
                            "Your data stays on your device. Lyneqo Caravan & Motorhome does not require an account. If you look up a UK registration, that plate is sent to a third-party vehicle data provider to return MOT, tax and vehicle details. Loading and other vehicle records are not uploaded."
                        )
                        paragraph(
                            "All calculations are estimates only. Always confirm your actual weights on a weighbridge before travelling, and check nose weight with a gauge when towing."
                        )
                        paragraph(
                            "Accident guidance is general help for a stressful moment, not legal advice. It cannot be correct for every country, police force or circumstance. Follow local emergency services and your insurer. If you look up another UK registration at the scene, that plate is sent to a third-party provider for MOT, tax and vehicle details only."
                        )
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .appScreenBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    AppSectionDivider()
                    AppPrimaryButton("Continue") {
                        viewModel.acceptDisclaimer(appState: appState, in: modelContext)
                    }
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.vertical, AppScreenMetrics.fieldSpacing)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(AppColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
