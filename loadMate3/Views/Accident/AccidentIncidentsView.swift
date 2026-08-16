import SwiftData
import SwiftUI
import UIKit

struct AccidentIncidentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query(sort: \AccidentRecord.occurredAt, order: .reverse) private var allRecords: [AccidentRecord]

    @State private var recorderRecord: AccidentRecord?
    @State private var showNewRecorder = false
    @State private var exportPDFData: Data?

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var records: [AccidentRecord] {
        guard let profile = activeProfile else { return [] }
        return AccidentStore.records(for: profile.id, from: allRecords)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                Text("Record what happened, photograph the scene, and look up other UK vehicles. This is a helper — not legal advice.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)

                AppPrimaryButton("Record an accident", systemImage: "exclamationmark.triangle.fill") {
                    showNewRecorder = true
                }

                if records.isEmpty {
                    AppSettingsSection("Past incidents", caption: "Incidents stay on this device with the vehicle.") {
                        Text("No incidents recorded yet.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        Text("Past incidents")
                            .font(.headline.weight(.semibold))
                        ForEach(records) { record in
                            incidentRow(record)
                        }
                    }
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
        }
        .appScreenBackground()
        .navigationTitle("Incidents")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showNewRecorder) {
            if let profile = activeProfile {
                AccidentRecorderView(vehicleID: profile.id, profile: profile)
            }
        }
        .fullScreenCover(item: $recorderRecord) { record in
            if let profile = activeProfile {
                AccidentRecorderView(vehicleID: profile.id, profile: profile, existing: record)
            }
        }
        .sheet(item: Binding(
            get: { exportPDFData.map { AccidentPDFShareItem(data: $0) } },
            set: { exportPDFData = $0?.data }
        )) { item in
            AccidentShareSheet(pdfData: item.data)
        }
    }

    private func incidentRow(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            Button {
                recorderRecord = record
            } label: {
                HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LyneqoTheme.Status.danger)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Formatters.dateTime(record.occurredAt))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("\(record.jurisdiction.displayName) · \(record.processBranch.displayName)")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                        if !record.otherVehiclesList.isEmpty {
                            Text(record.otherVehiclesList.map(\.displayRegistration).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)

            HStack {
                Button("Share pack") {
                    export(record)
                }
                .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Delete", role: .destructive) {
                    AccidentStore.delete(record, in: modelContext)
                }
                .font(.subheadline)
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }

    private func export(_ record: AccidentRecord) {
        guard let profile = activeProfile else { return }
        let photos: [(AccidentPhotoKind, UIImage)] = record.photosList.compactMap { photo in
            guard let image = AccidentPhotoStore.loadImage(for: photo, vehicleID: profile.id) else { return nil }
            return (photo.kind, image)
        }
        exportPDFData = AccidentEvidencePackBuilder.buildPDF(
            input: AccidentEvidencePackBuilder.makeInput(
                record: record,
                profile: profile,
                photoImages: photos
            )
        )
    }
}

private struct AccidentPDFShareItem: Identifiable {
    let id = UUID()
    let data: Data
}

struct AccidentShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pdfData: Data

    private var shareURL: URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Accident-Incident-\(UUID().uuidString).pdf")
        do {
            try pdfData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppScreenMetrics.sectionSpacing) {
                Text("Your incident pack is ready to share with your insurer.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share incident pack", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius))
                    }
                    .padding(.horizontal)
                } else {
                    Text("Could not prepare the PDF for sharing.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }

                Spacer()
            }
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AccidentEntryCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(LyneqoTheme.Status.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.top, 4)
            }
            .padding(AppScreenMetrics.cardInteriorPadding)
            .background(LyneqoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cardCornerRadiusLarge, style: .continuous)
                    .strokeBorder(LyneqoTheme.Status.danger.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
