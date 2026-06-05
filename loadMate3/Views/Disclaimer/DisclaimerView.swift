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
                    AppHeroSection(
                        systemImage: "scalemass.fill",
                        title: "LoadMate",
                        subtitle: "Plan your caravan loading with confidence"
                    )

                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        paragraph(
                            "LoadMate helps estimate caravan loading, nose weight impact, and key limit checks before you travel."
                        )
                        paragraph(
                            "With motorhomes, LoadMate models axle weights so you can see how your loading affects front and rear axle limits."
                        )
                        paragraph(
                            "Your data is stored on your device. If you use iCloud, LoadMate can sync your vehicles, trips, and checklists between your iPhone and iPad signed into the same Apple ID."
                        )
                        paragraph(
                            "LoadMate does not require an account and does not use a LoadMate backend server. With iCloud enabled, Apple syncs your app data through your iCloud account."
                        )
                        paragraph(
                            "Calculations are estimates only. Always physically check your actual weights before towing."
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
