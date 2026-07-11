import SwiftUI
import SwiftData

struct TyreSafetyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.usePadLayout) private var usePadLayout
    @Query private var profiles: [VehicleProfile]
    @Query private var appStates: [AppState]
    @Query private var tyreRecords: [TyreRecord]

    @State private var selectedRecord: TyreRecord?
    @State private var showSetup = false
    @State private var showQuickCheck = false
    @State private var showHistory = false
    @State private var showInfo = false

    private var activeProfile: VehicleProfile? {
        VehicleProfileStore.activeProfile(profiles: profiles, appState: AppStateStore.canonical(from: appStates))
    }

    private var activeRecords: [TyreRecord] {
        TyreStore.activeRecords(for: activeProfile, from: tyreRecords)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = activeProfile {
                    if activeRecords.isEmpty {
                        TyreSafetyEmptyStateView(profile: profile) {
                            showSetup = true
                        }
                    } else {
                        TyreSafetyOverviewView(
                            profile: profile,
                            records: activeRecords,
                            onSelectRecord: { selectedRecord = $0 },
                            onShowSetup: { showSetup = true },
                            onShowQuickCheck: { showQuickCheck = true },
                            onShowHistory: { showHistory = true },
                            onShowInfo: { showInfo = true }
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "No vehicle selected",
                        systemImage: "car.rear",
                        description: Text("Add or select a caravan or motorhome in Settings to use Tyre Safety.")
                    )
                }
            }
            .appScreenBackground()
            .appPrincipalTabTitle("Tyre Safety")
        }
        .sheet(isPresented: $showSetup) {
            if let profile = activeProfile {
                TyreSetupView(profile: profile, existingRecords: activeRecords)
            }
        }
        .sheet(item: $selectedRecord) { record in
            TyreDetailView(record: record)
        }
        .sheet(isPresented: $showQuickCheck) {
            if let profile = activeProfile {
                TyreQuickCheckView(profile: profile, records: activeRecords)
            }
        }
        .sheet(isPresented: $showHistory) {
            TyreHistoryView(records: activeRecords)
        }
        .sheet(isPresented: $showInfo) {
            TyreSafetyInfoView()
        }
    }
}

private struct TyreSafetyEmptyStateView: View {
    let profile: VehicleProfile
    let onSetup: () -> Void

    var body: some View {
        VStack(spacing: AppScreenMetrics.sectionSpacing) {
            Spacer()
            AppHeroSection(
                systemImage: "circle.hexagongrid.fill",
                title: "Set up your tyre layout",
                subtitle: "Record tyre age, pressure, condition and inspection history for this \(profile.kind.displayName.lowercased())."
            )
            AppPrimaryButton("Set up tyres", systemImage: "plus.circle.fill", action: onSetup)
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            Spacer()
        }
    }
}

private struct TyreSafetyOverviewView: View {
    let profile: VehicleProfile
    let records: [TyreRecord]
    let onSelectRecord: (TyreRecord) -> Void
    let onShowSetup: () -> Void
    let onShowQuickCheck: () -> Void
    let onShowHistory: () -> Void
    let onShowInfo: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                AppGroupedCard {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                        HStack(alignment: .center, spacing: AppScreenMetrics.tinySpacing) {
                            Spacer(minLength: 0)
                            Button(action: onShowQuickCheck) {
                                Image(systemName: "gauge.with.dots.needle.50percent")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Record tyre check")
                            .pointerHelp("Record tyre check")

                            Button(action: onShowHistory) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("View inspection history")
                            .pointerHelp("View inspection history")

                            Button(action: onShowSetup) {
                                Image(systemName: "circle.hexagongrid")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Change tyre layout")
                            .pointerHelp("Change tyre layout")

                            Button(action: onShowInfo) {
                                Image(systemName: "info.circle")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Tyre Safety information")
                            .pointerHelp("Tyre Safety information")
                        }

                        TyreDiagramView(profile: profile, records: records, onSelectRecord: onSelectRecord)
                    }
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, AppScreenMetrics.verticalScreenPadding)
            .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
        }
    }
}

private struct TyreDiagramView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let profile: VehicleProfile
    let records: [TyreRecord]
    let onSelectRecord: (TyreRecord) -> Void

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: AppScreenMetrics.controlSpacing) {
            Text(profile.kind == .caravan ? "Front / hitch" : "Front")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSupporting)

            if profile.kind == .caravan {
                caravanLayout
            } else {
                motorhomeLayout
            }
        }
    }

    private var caravanLayout: some View {
        VStack(spacing: AppScreenMetrics.controlSpacing) {
            if records.contains(where: { $0.position == .caravanLeft || $0.position == .caravanRight }) {
                HStack(spacing: AppScreenMetrics.controlSpacing) {
                    tyreButton(.caravanLeft)
                    tyreButton(.caravanRight)
                }
            } else {
                VStack(spacing: AppScreenMetrics.controlSpacing) {
                    HStack(spacing: AppScreenMetrics.controlSpacing) {
                        tyreButton(.caravanFrontLeft)
                        tyreButton(.caravanFrontRight)
                    }
                    HStack(spacing: AppScreenMetrics.controlSpacing) {
                        tyreButton(.caravanRearLeft)
                        tyreButton(.caravanRearRight)
                    }
                }
            }
            if records.contains(where: { $0.position == .caravanSpare }) {
                tyreButton(.caravanSpare)
            }
        }
    }

    private var motorhomeLayout: some View {
        VStack(spacing: AppScreenMetrics.controlSpacing) {
            HStack(spacing: AppScreenMetrics.controlSpacing) {
                tyreButton(.motorhomeFrontLeft)
                tyreButton(.motorhomeFrontRight)
            }
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemFill))
                .frame(height: 70)
                .overlay(Text("Motorhome body").font(.caption))

            if records.contains(where: { $0.position == .motorhomeRearLeftInner || $0.position == .motorhomeRearRightInner }) {
                HStack(spacing: AppScreenMetrics.smallSpacing) {
                    tyreButton(.motorhomeRearLeftOuter)
                    tyreButton(.motorhomeRearLeftInner)
                    Text("|").foregroundStyle(Color.secondary)
                    tyreButton(.motorhomeRearRightInner)
                    tyreButton(.motorhomeRearRightOuter)
                }
            } else {
                HStack(spacing: AppScreenMetrics.controlSpacing) {
                    tyreButton(.motorhomeRearLeft)
                    tyreButton(.motorhomeRearRight)
                }
            }

            if records.contains(where: { $0.position == .motorhomeSpare }) {
                tyreButton(.motorhomeSpare)
            }
        }
    }

    @ViewBuilder
    private func tyreButton(_ position: TyrePosition) -> some View {
        if let record = records.first(where: { $0.position == position && $0.isCurrentlyFitted }) {
            Button {
                onSelectRecord(record)
            } label: {
                tyreButtonLabel(for: record)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tyreAccessibilityLabel(for: record))
        }
    }

    private func tyreAccessibilityLabel(for record: TyreRecord) -> String {
        let details = record.alertMessages.isEmpty
            ? record.ageAssessment.status
            : record.alertMessages.joined(separator: ". ")
        return "\(record.displayName), \(details)"
    }

    @ViewBuilder
    private func tyreButtonLabel(for record: TyreRecord) -> some View {
        let statusColor = color(for: record.statusLevel)
        let imageToTextSpacing = isLandscape ? 0 : AppScreenMetrics.tinySpacing
        VStack(spacing: imageToTextSpacing) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 130, height: 130)

                if let image = diagramImage(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 122, height: 122)
                } else {
                    Image(systemName: record.statusLevel.symbolName)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }

                Image(systemName: record.statusLevel.symbolName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(statusColor))
                    .padding(4)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: isLandscape ? 1 : 2) {
                if record.alertMessages.isEmpty {
                    Text(record.ageAssessment.status)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ForEach(record.alertMessages, id: \.self) { message in
                        Text(message)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppColors.textSupporting)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: isLandscape ? 130 : .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func diagramImage(for record: TyreRecord) -> UIImage? {
        guard let photo = TyrePhotoStore.diagramPhoto(for: record) else { return nil }
        return TyrePhotoStore.loadImage(for: photo, vehicleID: profile.id)
    }

    private func color(for level: TyreStatusLevel) -> Color {
        switch level {
        case .current: return AppColors.green
        case .attention: return .orange
        case .action: return .red
        case .incomplete: return .secondary
        }
    }
}

private struct TyreSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: VehicleProfile
    let existingRecords: [TyreRecord]

    @State private var selectedLayout: TyreLayout
    @State private var includeSpare: Bool

    init(profile: VehicleProfile, existingRecords: [TyreRecord]) {
        self.profile = profile
        self.existingRecords = existingRecords
        let suggested = TyreStore.suggestedLayout(for: existingRecords, kind: profile.kind)
            ?? TyreSupport.layoutOptions(for: profile.kind).first
            ?? .caravanSingleAxle
        _selectedLayout = State(initialValue: suggested)
        _includeSpare = State(initialValue: existingRecords.contains(where: \.isSpare))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "circle.hexagongrid.fill",
                        title: "Set up your tyres",
                        subtitle: "Select the tyre arrangement fitted to this vehicle."
                    )

                    AppSettingsSection("Layout") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
                            ForEach(TyreSupport.layoutOptions(for: profile.kind)) { layout in
                                Button {
                                    selectedLayout = layout
                                } label: {
                                    HStack {
                                        Text(layout.displayName)
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        Image(systemName: selectedLayout == layout ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedLayout == layout ? Color.accentColor : Color.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                            Toggle(profile.kind == .caravan ? "Add spare tyre" : "Add spare tyre", isOn: $includeSpare)
                        }
                    }

                    if !existingRecords.isEmpty {
                        AppWarningBanner(message: "Changing the layout will keep your tyre history. Existing fitted tyres that no longer match the new layout will be archived rather than deleted.")
                    }

                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        AppPrimaryButton("Save layout") {
                            TyreStore.createLayout(for: profile, layout: selectedLayout, includeSpare: includeSpare, in: modelContext)
                            dismiss()
                        }
                        AppSecondaryButton("Skip for now") { dismiss() }
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Tyre layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct TyreDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(TyreSupport.pressureUnitAppStorageKey) private var pressureUnitRaw = PressureUnit.psi.rawValue

    let record: TyreRecord

    @State private var manufacturer: String
    @State private var modelName: String
    @State private var tyreSize: String
    @State private var loadIndex: String
    @State private var speedRating: String
    @State private var dateCode: String
    @State private var recommendedPressure: String
    @State private var latestPressure: String
    @State private var latestPressureDate: Date
    @State private var treadDepth: String
    @State private var latestInspectionDate: Date
    @State private var condition: TyreCondition
    @State private var notes: String
    @State private var installedDate: Date
    @State private var removedDate: Date
    @State private var isCurrentlyFitted: Bool
    @State private var dateCodeError: String?
    @State private var previewManufactureDate: Date?
    @State private var showInspection = false
    @State private var showHistory = false
    @State private var showReplaceConfirm = false
    @State private var isAnalyzingSidewall = false
    @State private var sidewallSuggestions: TyreSidewallSuggestions?
    @State private var sidewallAnalysisError: String?

    init(record: TyreRecord) {
        self.record = record
        let unit = PressureUnit(rawValue: UserDefaults.standard.string(forKey: TyreSupport.pressureUnitAppStorageKey) ?? PressureUnit.psi.rawValue) ?? .psi
        _manufacturer = State(initialValue: record.manufacturer)
        _modelName = State(initialValue: record.modelName)
        _tyreSize = State(initialValue: record.tyreSize)
        _loadIndex = State(initialValue: record.loadIndex)
        _speedRating = State(initialValue: record.speedRating)
        _dateCode = State(initialValue: record.dateCode)
        _recommendedPressure = State(initialValue: record.recommendedPressurePSI.map { Self.displayPressure($0, unit: unit) } ?? "")
        _latestPressure = State(initialValue: record.latestPressurePSI.map { Self.displayPressure($0, unit: unit) } ?? "")
        _latestPressureDate = State(initialValue: record.latestPressureDate ?? Date())
        _treadDepth = State(initialValue: record.latestTreadDepthMM.map { String(format: "%.1f", $0) } ?? "")
        _latestInspectionDate = State(initialValue: record.latestInspectionDate ?? Date())
        _condition = State(initialValue: record.condition)
        _notes = State(initialValue: record.notes)
        _installedDate = State(initialValue: record.installedDate ?? Date())
        _removedDate = State(initialValue: record.removedDate ?? Date())
        _isCurrentlyFitted = State(initialValue: record.isCurrentlyFitted)
        _previewManufactureDate = State(initialValue: record.manufactureDate)
    }

    private var manufactureDateAgeCaption: String {
        if let previewManufactureDate {
            return TyreSupport.ageText(for: previewManufactureDate)
        }
        return "Manufacture date not recorded"
    }

    private var pressureUnit: PressureUnit {
        PressureUnit(rawValue: pressureUnitRaw) ?? .psi
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: record.statusLevel.symbolName,
                        title: record.displayName,
                        subtitle: "\(record.ageText)\n\(record.pressureAssessment.status)\nCondition: \(record.condition.displayName)"
                    )

                    TyrePhotoGallerySection(
                        vehicleID: record.vehicleID,
                        record: record,
                        onAnalyzeSidewall: { photo in
                            analyzeSidewallPhoto(photo)
                        }
                    )

                    if isAnalyzingSidewall {
                        ProgressView("Analysing sidewall photo...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let sidewallAnalysisError {
                        AppWarningBanner(message: sidewallAnalysisError)
                    }

                    AppSettingsSection("Identification") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Manufacturer", placeholder: "e.g. Michelin", text: $manufacturer)
                            AppLabeledTextField("Model", placeholder: "e.g. Agilis", text: $modelName)
                            AppLabeledTextField("Tyre size", placeholder: "e.g. 225/75 R16", text: $tyreSize)
                            AppLabeledTextField("Load index", placeholder: "e.g. 121", text: $loadIndex)
                            AppLabeledTextField("Speed rating", placeholder: "e.g. R", text: $speedRating)
                            AppLabeledTextField(
                                "Manufacture date code",
                                caption: "The final four digits of the tyre identification marking show the week and year of manufacture. For example, 1221 means the tyre was manufactured during week 12 of 2021.",
                                placeholder: "e.g. 1221",
                                text: $dateCode,
                                keyboard: .numberPad,
                                onEditingEnded: commitDateCode
                            )
                            if let dateCodeError {
                                Text(dateCodeError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            Text(manufactureDateAgeCaption)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                        }
                    }

                    AppSettingsSection("Pressure") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Recommended cold pressure (\(pressureUnit.displayName))", placeholder: pressureUnit == .psi ? "65" : "4.5", text: $recommendedPressure, keyboard: .decimalPad)
                            AppLabeledTextField("Latest measured pressure (\(pressureUnit.displayName))", placeholder: pressureUnit == .psi ? "65" : "4.5", text: $latestPressure, keyboard: .decimalPad)
                            DatePicker("Date measured", selection: $latestPressureDate, displayedComponents: .date)
                        }
                    }

                    AppSettingsSection("Inspection") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            AppLabeledTextField("Tread depth (mm)", placeholder: "e.g. 6.0", text: $treadDepth, keyboard: .decimalPad)
                            Picker("Condition", selection: $condition) {
                                ForEach(TyreCondition.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            DatePicker("Date inspected", selection: $latestInspectionDate, displayedComponents: .date)
                            AppPrimaryButton("Record inspection", systemImage: "checklist") {
                                showInspection = true
                            }
                        }
                    }

                    AppSettingsSection("Installation") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            DatePicker("Date fitted", selection: $installedDate, displayedComponents: .date)
                            Toggle("Currently fitted", isOn: $isCurrentlyFitted)
                            DatePicker("Date removed", selection: $removedDate, displayedComponents: .date)
                        }
                    }

                    AppSettingsSection("Notes") {
                        AppNotesEditor(text: $notes)
                    }

                    VStack(spacing: AppScreenMetrics.controlSpacing) {
                        AppPrimaryButton("Save tyre details", systemImage: "checkmark.circle.fill") {
                            save()
                        }
                        AppSecondaryButton("View history") { showHistory = true }
                        AppSecondaryButton("Replace tyre") { showReplaceConfirm = true }
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Tyre details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showInspection) {
                TyreInspectionView(record: record)
            }
            .sheet(isPresented: $showHistory) {
                TyreRecordHistoryView(record: record)
            }
            .sheet(item: Binding(
                get: {
                    sidewallSuggestions?.hasAnySuggestion == true ? sidewallSuggestions : nil
                },
                set: { newValue in
                    sidewallSuggestions = newValue
                }
            )) { suggestions in
                TyreSidewallReviewSheet(suggestions: suggestions) { manufacturerValue, modelNameValue, tyreSizeValue, loadIndexValue, speedRatingValue, dateCodeValue in
                    applySidewallSuggestions(
                        manufacturer: manufacturerValue,
                        modelName: modelNameValue,
                        tyreSize: tyreSizeValue,
                        loadIndex: loadIndexValue,
                        speedRating: speedRatingValue,
                        dateCode: dateCodeValue
                    )
                }
            }
            .alert("Replace tyre", isPresented: $showReplaceConfirm) {
                Button("Copy manufacturer and model") {
                    _ = TyreStore.replaceTyre(record, copyManufacturerAndModel: true, in: modelContext)
                    dismiss()
                }
                Button("Do not copy manufacturer or model") {
                    _ = TyreStore.replaceTyre(record, copyManufacturerAndModel: false, in: modelContext)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The existing tyre will be marked as no longer fitted and a new tyre record will be created at the same position.")
            }
        }
    }

    private func save() {
        dateCodeError = nil
        let trimmedDateCode = dateCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDateCode.isEmpty {
            guard let parsed = TyreSupport.parseDateCode(trimmedDateCode) else {
                dateCodeError = "Enter a valid four-digit week and year code that is not in the future."
                return
            }
            record.dateCode = parsed.normalized
            record.manufactureWeek = parsed.week
            record.manufactureYear = parsed.year
            record.manufactureDate = parsed.manufactureDate
        } else {
            record.dateCode = ""
            record.manufactureWeek = nil
            record.manufactureYear = nil
            record.manufactureDate = nil
        }

        record.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        record.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        record.tyreSize = tyreSize.trimmingCharacters(in: .whitespacesAndNewlines)
        record.loadIndex = loadIndex.trimmingCharacters(in: .whitespacesAndNewlines)
        record.speedRating = speedRating.trimmingCharacters(in: .whitespacesAndNewlines)
        record.recommendedPressurePSI = parsePressure(recommendedPressure)
        record.latestPressurePSI = parsePressure(latestPressure)
        record.latestPressureDate = record.latestPressurePSI == nil ? nil : latestPressureDate
        record.latestTreadDepthMM = Double(treadDepth)
        record.latestInspectionDate = latestInspectionDate
        record.condition = condition
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.installedDate = installedDate
        record.removedDate = isCurrentlyFitted ? nil : removedDate
        record.isCurrentlyFitted = isCurrentlyFitted
        record.updatedAt = Date()

        try? modelContext.save()
        dismiss()
    }

    private func parsePressure(_ input: String) -> Double? {
        guard let displayValue = Double(input) else { return nil }
        return TyreSupport.convertPressure(displayValue, from: pressureUnit, to: .psi)
    }

    private func analyzeSidewallPhoto(_ photo: TyrePhoto) {
        isAnalyzingSidewall = true
        sidewallAnalysisError = nil
        Task {
            do {
                let suggestions = try await TyreSidewallOCR.analyze(photo: photo, vehicleID: record.vehicleID)
                await MainActor.run {
                    isAnalyzingSidewall = false
                    if suggestions.hasAnySuggestion {
                        sidewallSuggestions = suggestions
                    } else {
                        sidewallAnalysisError = suggestions.confidenceNotes.first ?? "No reliable sidewall text was recognised. Try a clearer photo."
                    }
                }
            } catch {
                await MainActor.run {
                    isAnalyzingSidewall = false
                    sidewallAnalysisError = "Could not analyse the sidewall photo on this device. Try a clearer photo and check the values manually."
                }
            }
        }
    }

    private func applySidewallSuggestions(
        manufacturer manufacturerValue: String?,
        modelName modelNameValue: String?,
        tyreSize tyreSizeValue: String?,
        loadIndex loadIndexValue: String?,
        speedRating speedRatingValue: String?,
        dateCode dateCodeValue: String?
    ) {
        if let manufacturerValue, !manufacturerValue.isEmpty {
            manufacturer = manufacturerValue
        }
        if let modelNameValue, !modelNameValue.isEmpty {
            modelName = modelNameValue
        }
        if let tyreSizeValue, !tyreSizeValue.isEmpty {
            tyreSize = tyreSizeValue
        }
        if let loadIndexValue, !loadIndexValue.isEmpty {
            loadIndex = loadIndexValue
        }
        if let speedRatingValue, !speedRatingValue.isEmpty {
            speedRating = speedRatingValue
        }
        if let dateCodeValue, !dateCodeValue.isEmpty {
            dateCode = dateCodeValue
            commitDateCode()
        }
    }

    private func commitDateCode() {
        dateCodeError = nil
        let trimmedDateCode = dateCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDateCode.isEmpty else {
            previewManufactureDate = nil
            return
        }

        guard let parsed = TyreSupport.parseDateCode(trimmedDateCode) else {
            previewManufactureDate = nil
            dateCodeError = "Enter a valid four-digit week and year code that is not in the future."
            return
        }

        dateCode = parsed.normalized
        previewManufactureDate = parsed.manufactureDate
    }

    private static func displayPressure(_ pressurePSI: Double, unit: PressureUnit) -> String {
        let converted = TyreSupport.convertPressure(pressurePSI, from: .psi, to: unit)
        return String(format: unit == .psi ? "%.0f" : "%.1f", converted)
    }
}

struct TyreInspectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(TyreSupport.pressureUnitAppStorageKey) private var pressureUnitRaw = PressureUnit.psi.rawValue

    let record: TyreRecord

    @State private var inspectionDate = Date()
    @State private var pressure = ""
    @State private var treadDepth = ""
    @State private var hasCuts = false
    @State private var hasBulges = false
    @State private var hasCracking = false
    @State private var hasUnevenWear = false
    @State private var hasEmbeddedObjects = false
    @State private var valveAppearsSound = true
    @State private var wheelNutsChecked = true
    @State private var overallCondition: TyreCondition = .good
    @State private var notes = ""
    @State private var pendingPhotos: [(UIImage, TyrePhotoKind)] = []

    private var pressureUnit: PressureUnit {
        PressureUnit(rawValue: pressureUnitRaw) ?? .psi
    }

    private var requiresReview: Bool {
        hasCuts || hasBulges || hasCracking || hasUnevenWear || hasEmbeddedObjects || overallCondition == .monitor || overallCondition == .replace
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "checklist",
                        title: "Tyre inspection",
                        subtitle: record.displayName
                    )

                    AppSettingsSection("Inspection") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            DatePicker("Inspection date", selection: $inspectionDate, displayedComponents: .date)
                            AppLabeledTextField("Pressure (\(pressureUnit.displayName))", placeholder: pressureUnit == .psi ? "65" : "4.5", text: $pressure, keyboard: .decimalPad)
                            AppLabeledTextField("Tread depth (mm)", placeholder: "e.g. 5.8", text: $treadDepth, keyboard: .decimalPad)
                        }
                    }

                    AppSettingsSection("Visible checks") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            defectToggle("Visible cuts", value: $hasCuts)
                            defectToggle("Bulges", value: $hasBulges)
                            defectToggle("Cracking or perishing", value: $hasCracking)
                            defectToggle("Uneven wear", value: $hasUnevenWear)
                            defectToggle("Embedded objects", value: $hasEmbeddedObjects)
                            defectToggle("Valve appears sound", value: $valveAppearsSound, positiveLabel: true)
                            defectToggle("Wheel nuts checked", value: $wheelNutsChecked, positiveLabel: true)
                            Picker("Overall condition", selection: $overallCondition) {
                                ForEach(TyreCondition.allCases.filter { $0 != .notChecked }) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            AppNotesEditor(text: $notes)
                        }
                    }

                    TyrePendingPhotoSection(pendingImages: $pendingPhotos)

                    if requiresReview {
                        AppWarningBanner(message: "Professional inspection recommended before travelling.")
                    }

                    AppPrimaryButton("Save inspection", systemImage: "checkmark.circle.fill") {
                        let inspection = TyreStore.addInspection(
                            to: record,
                            inspectionDate: inspectionDate,
                            pressurePSI: parsePressure(pressure),
                            treadDepthMM: Double(treadDepth),
                            hasCuts: hasCuts,
                            hasBulges: hasBulges,
                            hasCracking: hasCracking,
                            hasUnevenWear: hasUnevenWear,
                            hasEmbeddedObjects: hasEmbeddedObjects,
                            valveAppearsSound: valveAppearsSound,
                            wheelNutsChecked: wheelNutsChecked,
                            overallCondition: overallCondition,
                            notes: notes,
                            in: modelContext
                        )
                        TyrePhotoStore.savePending(
                            images: pendingPhotos,
                            vehicleID: record.vehicleID,
                            record: record,
                            inspection: inspection,
                            in: modelContext
                        )
                        dismiss()
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func defectToggle(_ title: String, value: Binding<Bool>, positiveLabel: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Picker(title, selection: value) {
                Text(positiveLabel ? "No" : "No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func parsePressure(_ input: String) -> Double? {
        guard let displayValue = Double(input) else { return nil }
        return TyreSupport.convertPressure(displayValue, from: pressureUnit, to: .psi)
    }
}

private struct TyreQuickCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(TyreSupport.pressureUnitAppStorageKey) private var pressureUnitRaw = PressureUnit.psi.rawValue

    let profile: VehicleProfile
    let records: [TyreRecord]

    @State private var inspectionDate = Date()
    @State private var notes = ""
    @State private var pressureEntries: [UUID: String]
    @State private var treadEntries: [UUID: String]

    init(profile: VehicleProfile, records: [TyreRecord]) {
        self.profile = profile
        self.records = records
        var pressureEntries: [UUID: String] = [:]
        var treadEntries: [UUID: String] = [:]
        let unit = PressureUnit(rawValue: UserDefaults.standard.string(forKey: TyreSupport.pressureUnitAppStorageKey) ?? PressureUnit.psi.rawValue) ?? .psi
        for record in records {
            if let latest = record.latestPressurePSI {
                let converted = TyreSupport.convertPressure(latest, from: .psi, to: unit)
                pressureEntries[record.id] = String(format: unit == .psi ? "%.0f" : "%.1f", converted)
            }
            if let tread = record.latestTreadDepthMM {
                treadEntries[record.id] = String(format: "%.1f", tread)
            }
        }
        _pressureEntries = State(initialValue: pressureEntries)
        _treadEntries = State(initialValue: treadEntries)
    }

    private var pressureUnit: PressureUnit {
        PressureUnit(rawValue: pressureUnitRaw) ?? .psi
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "gauge.with.dots.needle.50percent",
                        title: "Record tyre check",
                        subtitle: profile.name
                    )

                    AppSettingsSection("Check details") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            DatePicker("Check date", selection: $inspectionDate, displayedComponents: .date)
                            AppNotesEditor(text: $notes)
                        }
                    }

                    AppSettingsSection("Pressures") {
                        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                            ForEach(records) { record in
                                VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                                    Text(record.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    AppBoundedTextField(
                                        placeholder: pressureUnit == .psi ? "PSI" : "Bar",
                                        text: Binding(
                                            get: { pressureEntries[record.id] ?? "" },
                                            set: { pressureEntries[record.id] = $0 }
                                        ),
                                        keyboard: .decimalPad
                                    )
                                    AppBoundedTextField(
                                        placeholder: "Optional tread depth (mm)",
                                        text: Binding(
                                            get: { treadEntries[record.id] ?? "" },
                                            set: { treadEntries[record.id] = $0 }
                                        ),
                                        keyboard: .decimalPad
                                    )
                                }
                            }
                        }
                    }

                    AppPrimaryButton("Save all readings", systemImage: "checkmark.circle.fill") {
                        var pressurePSI: [UUID: Double] = [:]
                        var treadMM: [UUID: Double] = [:]
                        for record in records {
                            if let entry = pressureEntries[record.id], let value = Double(entry) {
                                pressurePSI[record.id] = TyreSupport.convertPressure(value, from: pressureUnit, to: .psi)
                            }
                            if let entry = treadEntries[record.id], let value = Double(entry) {
                                treadMM[record.id] = value
                            }
                        }
                        TyreStore.saveQuickCheck(
                            records: records,
                            pressureEntriesPSI: pressurePSI,
                            treadDepthEntries: treadMM,
                            inspectionDate: inspectionDate,
                            notes: notes,
                            in: modelContext
                        )
                        dismiss()
                    }
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Quick check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct TyreHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [TyreRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(records) { record in
                    Section(record.displayName) {
                        if record.inspectionsList.isEmpty {
                            Text("No inspection history recorded yet.")
                                .foregroundStyle(AppColors.textSupporting)
                        } else {
                            ForEach(record.inspectionsList) { inspection in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(Formatters.date(inspection.inspectionDate))
                                        .font(.subheadline.weight(.semibold))
                                    Text("Condition: \(inspection.overallCondition.displayName)")
                                        .font(.caption)
                                    if let pressure = inspection.pressurePSI {
                                        Text("Pressure: \(Formatters.pressure(pressure, unit: .psi))")
                                            .font(.caption)
                                    }
                                    if let tread = inspection.treadDepthMM {
                                        Text("Tread depth: \(String(format: "%.1f", tread)) mm")
                                            .font(.caption)
                                    }
                                    if !inspection.notes.isEmpty {
                                        Text(inspection.notes)
                                            .font(.caption)
                                    }
                                    TyreInspectionPhotoStrip(
                                        photos: inspection.photosList,
                                        vehicleID: record.vehicleID
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inspection history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct TyreRecordHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let record: TyreRecord

    var body: some View {
        NavigationStack {
            List {
                if !record.generalPhotosList().isEmpty {
                    Section("Tyre photos") {
                        TyreInspectionPhotoStrip(
                            photos: record.generalPhotosList(),
                            vehicleID: record.vehicleID
                        )
                    }
                }

                if !record.inspectionsList.isEmpty {
                    Section("Inspections") {
                        ForEach(record.inspectionsList) { inspection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Formatters.date(inspection.inspectionDate))
                                    .font(.subheadline.weight(.semibold))
                                Text("Condition: \(inspection.overallCondition.displayName)")
                                    .font(.caption)
                                if let pressure = inspection.pressurePSI {
                                    Text("Pressure: \(Formatters.pressure(pressure, unit: .psi))")
                                        .font(.caption)
                                }
                                if let tread = inspection.treadDepthMM {
                                    Text("Tread depth: \(String(format: "%.1f", tread)) mm")
                                        .font(.caption)
                                }
                                if !inspection.notes.isEmpty {
                                    Text(inspection.notes)
                                        .font(.caption)
                                }
                                TyreInspectionPhotoStrip(
                                    photos: inspection.photosList,
                                    vehicleID: record.vehicleID
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(record.displayName) history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct TyreSafetyInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
                    AppHeroSection(
                        systemImage: "info.circle",
                        title: "Tyre Safety information",
                        subtitle: "Advisory guidance only"
                    )
                    Text(TyreSupport.tyreDisclaimer)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Caravan tyres often cover low mileages but can still deteriorate with age, sunlight, loading and long periods of standing. Industry guidance commonly recommends reviewing replacement at around five years and avoiding continued use beyond seven years.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Tyre photos are stored on this device for your records. LoadMate does not analyse photos or draw conclusions about tyre condition from images.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.verticalScreenPadding)
                .padding(.bottom, AppScreenMetrics.bottomScrollPadding)
            }
            .appScreenBackground()
            .navigationTitle("Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct AppNotesEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 120)
            .padding(8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            }
    }
}
