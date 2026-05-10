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
                        systemImage: "exclamationmark.shield.fill",
                        title: "Safety disclaimer",
                        subtitle: "Please read this carefully before using estimates from LoadMate."
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        paragraph("This app is an estimation tool only.")
                        paragraph("Always physically measure nose weight and verify total caravan weight.")
                        paragraph("Do not exceed MTPLM, tow-ball limits, or vehicle limits.")
                        paragraph("By continuing, you accept that estimates may be incorrect.")
                    }

                    Text("If you are unsure, consult your caravan and vehicle documentation or a qualified technician.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .appScreenBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    AppSectionDivider()
                    AppPrimaryButton("I understand and accept", systemImage: "checkmark.circle.fill") {
                        viewModel.acceptDisclaimer(appState: appState, in: modelContext)
                    }
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.vertical, 16)
                    .background(AppColors.backgroundPrimary)
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
