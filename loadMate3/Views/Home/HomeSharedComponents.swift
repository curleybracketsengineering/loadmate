import SwiftUI
import SwiftData

// MARK: - Trip selector (mockup style)

struct HomeTripSelectorBar: View {
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let trips: [Trip]
    let activeTrip: Trip?

    @Binding var showAddTrip: Bool
    @Binding var tripPendingRename: Trip?
    @Binding var tripRenameField: String

    var body: some View {
        HStack(spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: profile.kind == .motorhome ? "bus.fill" : "car.rear.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Menu {
                ForEach(trips) { trip in
                    Button {
                        TripStore.setActive(trip, on: profile, in: modelContext)
                    } label: {
                        if trip.id == activeTrip?.id {
                            Label(trip.name, systemImage: "checkmark")
                        } else {
                            Text(trip.name)
                        }
                    }
                }
                Divider()
                Button {
                    showAddTrip = true
                } label: {
                    Label("New trip", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(activeTrip?.name ?? "Select trip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button("Change Trip") {
                if let trip = activeTrip {
                    tripPendingRename = trip
                    tripRenameField = trip.name
                } else if let first = trips.first {
                    tripPendingRename = first
                    tripRenameField = first.name
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(LyneqoTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Load overview card

struct LoadOverviewCard: View {
    let profile: VehicleProfile
    let caravanSummary: WeightSummary?
    let motorhomeSummary: MotorhomeWeightSummary?
    var onViewFullSummary: (() -> Void)? = nil

    private var isSafe: Bool {
        if let summary = caravanSummary { return summary.isOverallSafe }
        if let summary = motorhomeSummary { return summary.isOverallSafe }
        return false
    }

    private var currentWeightKg: Double {
        caravanSummary?.totalWeightKg ?? motorhomeSummary?.totalWeightKg ?? 0
    }

    private var limitKg: Double {
        profile.mtplmKg
    }

    private var noseLabel: String {
        profile.kind == .caravan ? "Nose Weight" : "Tow Ball"
    }

    private var noseCurrentKg: Double {
        if let summary = caravanSummary { return summary.estimatedNoseWeightKg }
        if let summary = motorhomeSummary { return summary.towBarLoadKg }
        return 0
    }

    private var noseLimitKg: Double {
        if profile.kind == .caravan { return profile.maxTowBarKg }
        return profile.maxTowBarKg
    }

    private var availableKg: Double {
        caravanSummary?.availableWeightKg ?? motorhomeSummary?.availableGrossKg ?? 0
    }

    private var fillFraction: Double {
        guard limitKg > 0 else { return 0 }
        return min(max(currentWeightKg / limitKg, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            HStack {
                Text("Load Overview")
                    .font(.headline.weight(.semibold))
                Spacer()
                if isSafe {
                    Label("SAFE", systemImage: "checkmark.shield.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.green.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Label("CHECK", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .top, spacing: AppScreenMetrics.smallSpacing) {
                metricColumn(
                    title: "Current Weight",
                    value: Formatters.kg(currentWeightKg),
                    caption: limitKg > 0 ? "of \(Formatters.kg(limitKg))" : nil
                )
                metricColumn(
                    title: noseLabel,
                    value: Formatters.kg(noseCurrentKg),
                    caption: noseLimitKg > 0 ? "of \(Formatters.kg(noseLimitKg))" : nil
                )
                metricColumn(
                    title: "Available",
                    value: Formatters.kg(availableKg),
                    caption: nil
                )
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LyneqoTheme.softTeal)
                    Capsule()
                        .fill(isSafe ? Color.accentColor : AppColors.orange)
                        .frame(width: geo.size.width * fillFraction)
                }
            }
            .frame(height: 8)

            if let onViewFullSummary {
                Button(action: onViewFullSummary) {
                    HStack {
                        Text("View full summary")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                .strokeBorder(LyneqoTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }

    private func metricColumn(title: String, value: String, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Quick action tile

struct HomeQuickActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppScreenMetrics.smallSpacing) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppScreenMetrics.cardInteriorPadding)
            .background(LyneqoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(LyneqoTheme.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hub list row

struct HomeHubListRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(AppScreenMetrics.cardInteriorPadding)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workflow metrics strip

struct LoadWorkflowMetricsStrip: View {
    let profile: VehicleProfile
    let caravanSummary: WeightSummary?
    let motorhomeSummary: MotorhomeWeightSummary?

    private var totalLoadKg: Double {
        caravanSummary?.totalWeightKg ?? motorhomeSummary?.totalWeightKg ?? 0
    }

    private var limitKg: Double {
        profile.mtplmKg
    }

    private var payloadLeftKg: Double {
        caravanSummary?.availableWeightKg ?? motorhomeSummary?.availableGrossKg ?? 0
    }

    private var noseKg: Double {
        caravanSummary?.estimatedNoseWeightKg ?? motorhomeSummary?.towBarLoadKg ?? 0
    }

    private var noseCaption: String {
        if profile.kind == .caravan {
            if let summary = caravanSummary, summary.isOverallSafe { return "within target" }
            return "check range"
        }
        return motorhomeSummary?.isTowBarMeasurementMissing == true ? "enter on Load" : "recorded"
    }

    var body: some View {
        HStack(spacing: AppScreenMetrics.smallSpacing) {
            stripMetric(title: "Total Trip Load", value: Formatters.kg(totalLoadKg), caption: limitKg > 0 ? "of \(Formatters.kg(limitKg))" : nil)
            stripMetric(title: "Payload Left", value: Formatters.kg(payloadLeftKg), caption: "remaining")
            stripMetric(title: profile.kind == .caravan ? "Est. Nose Weight" : "Tow Ball Load", value: Formatters.kg(noseKg), caption: noseCaption)
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(LyneqoTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }

    private func stripMetric(title: String, value: String, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.textSupporting)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Workflow step indicator

enum LoadWorkflowStep: Int, CaseIterable, Identifiable {
    case items = 1
    case locations = 2
    case summary = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .items: return "Items"
        case .locations: return "Locations"
        case .summary: return "Summary"
        }
    }
}

struct LoadWorkflowStepIndicator: View {
    @Binding var step: LoadWorkflowStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LoadWorkflowStep.allCases) { workflowStep in
                Button {
                    step = workflowStep
                } label: {
                    VStack(spacing: 6) {
                        Text("\(workflowStep.rawValue). \(workflowStep.title)")
                            .font(.subheadline.weight(step == workflowStep ? .semibold : .regular))
                            .foregroundStyle(step == workflowStep ? Color.accentColor : AppColors.textSupporting)
                        Capsule()
                            .fill(step == workflowStep ? Color.accentColor : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Optional nav title

struct OptionalPrincipalTabTitle: ViewModifier {
    let title: String?

    func body(content: Content) -> some View {
        if let title {
            content.appPrincipalTabTitle(title)
        } else {
            content
        }
    }
}
