import SwiftUI

// MARK: - Check row

struct SummaryCheckRow<Check: SummaryCheckGuidance>: View {
    let check: Check
    let onShowDetails: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
            Image(systemName: check.isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(check.isPositive ? AppColors.green : AppColors.orange)
                .accessibilityHidden(true)

            Text(check.message)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onShowDetails) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show guidance for \(check.title)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(check.title). \(check.message)")
        .accessibilityHint("Opens safety guidance")
    }
}

// MARK: - Detail sheet

struct SummaryCheckDetailSheet<Check: SummaryCheckGuidance>: View {
    let check: Check
    @Environment(\.dismiss) private var dismiss
    @State private var sheetDetent: PresentationDetent = .fraction(0.92)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                        Image(systemName: check.isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(check.isPositive ? AppColors.green : AppColors.orange)
                            .accessibilityHidden(true)

                        Text(check.message)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    guidanceBlock(
                        heading: "Why it matters",
                        body: check.whyItMatters
                    )

                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        Text("What to do")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.secondary)

                        ForEach(Array(check.actionSteps.enumerated()), id: \.offset) { _, step in
                            HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                                    .accessibilityHidden(true)
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.fieldSpacing)
                .padding(.bottom, AppScreenMetrics.sectionSpacingLoose)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(check.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.92)], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func guidanceBlock(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
            Text(heading)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }
}

// MARK: - Guidance protocol

protocol SummaryCheckGuidance {
    var id: String { get }
    var title: String { get }
    var message: String { get }
    var isPositive: Bool { get }
    var whyItMatters: String { get }
    var actionSteps: [String] { get }
}

extension CaravanSummaryCheck: SummaryCheckGuidance {}
extension MotorhomeSummaryCheck: SummaryCheckGuidance {}

// MARK: - Legacy aliases

typealias CaravanSummaryCheckRow = SummaryCheckRow<CaravanSummaryCheck>
typealias CaravanSummaryCheckDetailSheet = SummaryCheckDetailSheet<CaravanSummaryCheck>
