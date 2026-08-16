import Combine
import Contacts
import CoreLocation
import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AccidentRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.vehicleLookup) private var vehicleLookup

    let vehicleID: UUID
    let profile: VehicleProfile
    var existing: AccidentRecord?

    @State private var record: AccidentRecord?
    @State private var step: AccidentRecorderStep = .scene
    @StateObject private var locationCapture = AccidentLocationCapture()
    @State private var exportPDFData: Data?
    @State private var lookingUpVehicleID: UUID?
    @State private var lookingUpOwnVehicle = false
    @State private var scanningVehicle: AccidentOtherVehicle?
    @State private var showPlateCamera = false
    @State private var showPlateLibrary = false
    @State private var plateLibraryItem: PhotosPickerItem?
    @State private var plateSuggestions: [String] = []
    @State private var showPlateSuggestions = false
    @State private var isScanningPlate = false
    @State private var locationDraft: CLLocationCoordinate2D?
    @State private var locationNeedsConfirmation = false
    @State private var locationRefreshRequested = false
    @State private var locationDraftCountryCode: String?
    @State private var locationMapRevision = 0
    @State private var isSearchingLocation = false
    @State private var isConfirmingLocation = false
    @State private var locationSearchError: String?
    @State private var pinJurisdiction: AccidentJurisdiction?
    @State private var showAskMIDInfo = false
    @State private var showMyCardPicker = false
    @State private var myCardError: String?

    private var guidance: AccidentGuidanceResult {
        guard let record else {
            return AccidentGuidance.evaluate(AccidentGuidanceInput(vehicleKind: profile.kind))
        }
        return AccidentGuidance.evaluate(AccidentStore.guidanceInput(for: record, profile: profile))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AccidentStepIndicator(step: $step)
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.top, AppScreenMetrics.smallSpacing)
                Text("Saved on this device as you go.")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSupporting)
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.top, 2)

                ScrollView {
                    Group {
                        if let record {
                            stepContent(record)
                        } else {
                            ProgressView()
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.top, AppScreenMetrics.fieldSpacing)
                    .padding(.bottom, 120)
                }
            }
            .appScreenBackground()
            .navigationTitle("Accident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    AppSectionDivider()
                    HStack(spacing: AppScreenMetrics.controlSpacing) {
                        if step != .scene {
                            AppSecondaryButton("Back") {
                                move(by: -1)
                            }
                        }
                        AppPrimaryButton(step == .review ? "Done" : "Next") {
                            if step == .review {
                                dismiss()
                            } else {
                                move(by: 1)
                            }
                        }
                    }
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.vertical, AppScreenMetrics.fieldSpacing)
                    .background(.ultraThinMaterial)
                }
            }
            .onAppear {
                ensureRecord()
                locationCapture.requestIfNeeded()
            }
            .onChange(of: locationCapture.coordinate?.latitude) { _, _ in
                applyLocationIfNeeded()
            }
            .sheet(item: Binding(
                get: { exportPDFData.map { IdentifiedPDF(data: $0) } },
                set: { exportPDFData = $0?.data }
            )) { item in
                AccidentShareSheet(pdfData: item.data)
            }
            .sheet(isPresented: $showPlateCamera) {
                AccidentImagePicker(sourceType: .camera) { image in
                    analyzePlate(image)
                }
            }
            .photosPicker(isPresented: $showPlateLibrary, selection: $plateLibraryItem, matching: .images)
            .onChange(of: plateLibraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            analyzePlate(image)
                            plateLibraryItem = nil
                        }
                    }
                }
            }
            .confirmationDialog("Use this registration?", isPresented: $showPlateSuggestions, titleVisibility: .visible) {
                ForEach(plateSuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        applyPlateSuggestion(suggestion)
                    }
                }
                Button("Cancel", role: .cancel) {
                    scanningVehicle = nil
                    plateSuggestions = []
                }
            } message: {
                Text("Choose the plate that matches the other vehicle.")
            }
            .alert("Insurance Lookup Service", isPresented: $showAskMIDInfo) {
                Button("Open askMID") {
                    openURL(AccidentLinks.askMID)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("If you cannot confirm the other driver’s insurance, askMID can look up their details after an accident for £10. You usually get the insurer name, policy number and claims contact details. This is not proof of cover.")
            }
            .sheet(isPresented: $showMyCardPicker) {
                MyCardContactPicker { contact in
                    if let record {
                        applyMyCard(contact, to: record)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func stepContent(_ record: AccidentRecord) -> some View {
        switch step {
        case .scene:
            sceneStep(record)
        case .doNow:
            doNowStep(record)
        case .vehicles:
            vehiclesStep(record)
        case .photos:
            photosStep(record)
        case .details:
            detailsStep(record)
        case .review:
            reviewStep(record)
        }
    }

    private func sceneStep(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                Text("Have you had an accident?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LyneqoTheme.deepNavy)
                Text("First, check that everyone is safe.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSupporting)
            }

            AppSettingsSection("Safety", caption: "Answer what you can. You can change this later.") {
                sceneQuestion(
                    "Anyone injured?",
                    isOn: boolBinding(record, \.anyoneInjured),
                    advice: "Do not move an injured person unless they are in immediate danger.",
                    callNumber: record.jurisdiction.emergencyNumber
                )
                sceneQuestion(
                    "Road blocked, fire, or people in danger?",
                    isOn: boolBinding(record, \.sceneUnsafeOrBlocked),
                    advice: "Move to a safe place if you can do so without putting anyone at greater risk.",
                    callNumber: record.jurisdiction.emergencyNumber
                )
                sceneQuestion(
                    "Suspect drink, drugs or violence?",
                    isOn: boolBinding(record, \.suspectedImpairmentOrViolence),
                    advice: "Call from a safe place. Do not confront the other driver.",
                    callNumber: record.jurisdiction.emergencyNumber
                )
                sceneQuestion(
                    "Other driver left or is leaving?",
                    isOn: boolBinding(record, \.hitAndRun),
                    advice: "Do not follow them. Note the plate, vehicle and direction of travel.",
                    callNumber: record.jurisdiction.emergencyNumber
                )
            }

            AppSettingsSection(
                "Where did it happen?",
                caption: "Use your current position, search, or drag the pin. Next keeps this location."
            ) {
                HStack(spacing: AppScreenMetrics.smallSpacing) {
                    TextField(
                        "Road, place or postcode",
                        text: stringBinding(record, \.locationDescription)
                    )
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit {
                        searchLocation(record)
                    }

                    Button {
                        searchLocation(record)
                    } label: {
                        if isSearchingLocation {
                            ProgressView()
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(
                        isSearchingLocation
                            || record.locationDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .accessibilityLabel("Find location on map")
                }

                if let locationSearchError {
                    Text(locationSearchError)
                        .font(.caption)
                        .foregroundStyle(LyneqoTheme.Status.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    locationRefreshRequested = true
                    locationCapture.requestCurrentLocation()
                } label: {
                    Label("Use my current location", systemImage: "location.fill")
                }
                .font(.subheadline.weight(.semibold))

                if let coordinate = displayedCoordinate(for: record) {
                    AccidentLocationMap(
                        coordinate: Binding(
                            get: { displayedCoordinate(for: record) ?? coordinate },
                            set: { updateLocationDraft($0) }
                        )
                    )
                    .id(locationMapRevision)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))

                    if locationNeedsConfirmation {
                        Text("Drag the pin if this is wrong. Next saves this location.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    } else {
                        Text("Location saved. You can still drag the pin to correct it.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                } else if locationCapture.authorizationDenied {
                    Text("Location permission is off. Search for the place above, or enable location access in Settings.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                } else {
                    ProgressView("Finding your location…")
                        .font(.caption)
                }

                Picker("Country or region", selection: jurisdictionBinding(record)) {
                    ForEach(AccidentJurisdiction.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.menu)

                if let pinJurisdiction, pinJurisdiction != record.jurisdiction {
                    AppWarningBanner(
                        message: "The map pin looks like \(pinJurisdiction.displayName), but the country is set to \(record.jurisdiction.displayName). Change whichever is wrong."
                    )
                }

                DisclosureGroup("More location detail") {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                        Text("Suggested from the map pin. Change it if the suggestion is wrong.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                        TextField("What3Words (optional)", text: stringBinding(record, \.what3Words))
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.top, AppScreenMetrics.smallSpacing)
                }
                .font(.subheadline.weight(.semibold))
            }

            AppSettingsSection("When") {
                DatePicker(
                    "Date and time",
                    selection: occurredBinding(record),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }

    @ViewBuilder
    private func sceneQuestion(
        _ title: String,
        isOn: Binding<Bool>,
        advice: String,
        callNumber: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            Toggle(title, isOn: isOn)
            if isOn.wrappedValue {
                Label(advice, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(LyneqoTheme.Status.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                Button("Call \(callNumber)") {
                    if let url = URL(string: "tel://\(callNumber)") {
                        openURL(url)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOn.wrappedValue)
    }

    private func doNowStep(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
            ForEach(doNowPriorityCards) { card in
                AccidentGuidanceCardView(card: card) { url in
                    openURL(url)
                }
            }

            AppSettingsSection("At the scene") {
                Toggle(
                    "No other vehicle involved?",
                    isOn: Binding(
                        get: { record.noOtherVehicle },
                        set: {
                            record.noOtherVehicle = $0
                            if $0 {
                                record.detailsExchanged = false
                                record.otherDriverRefused = false
                            }
                            AccidentStore.refreshProcessBranch(for: record, profile: profile)
                            AccidentStore.save(record, in: modelContext)
                        }
                    )
                )

                if !record.noOtherVehicle {
                    Toggle("Details exchanged?", isOn: boolBinding(record, \.detailsExchanged))
                    Toggle("Saw their insurance or Green Card?", isOn: boolBinding(record, \.insuranceCertificateSeen))
                    Toggle("They refused to cooperate?", isOn: boolBinding(record, \.otherDriverRefused))
                }

                Toggle("Police informed?", isOn: boolBinding(record, \.policeReported))
                if record.policeReported {
                    TextField("Police reference", text: stringBinding(record, \.policeReference))
                }

                if !record.noOtherVehicle {
                    Text("If they show documents and agree, photograph them here. Photos stay on this device.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)

                    AccidentDocumentPhotoCaptureRow(
                        vehicleID: vehicleID,
                        record: record,
                        kind: .documents,
                        emptyIcon: "doc.text.image",
                        confirmationMessage: "Only photograph insurance or a Green Card if they show it. Do not take documents from them.",
                        onSaved: {
                            record.insuranceCertificateSeen = true
                            AccidentStore.save(record, in: modelContext)
                        }
                    )

                    AccidentDocumentPhotoCaptureRow(
                        vehicleID: vehicleID,
                        record: record,
                        kind: .drivingLicence,
                        emptyIcon: "person.text.rectangle",
                        captionFilter: "scene-driving-licence",
                        captionOnSave: "scene-driving-licence",
                        confirmationMessage: "Only continue if the driver has offered the licence and agrees to it being photographed."
                    )
                }
            }

            ForEach(doNowFollowUpCards) { card in
                AccidentGuidanceCardView(card: card) { url in
                    openURL(url)
                }
            }
        }
    }

    private var doNowPriorityCards: [AccidentGuidanceCard] {
        guidance.cards.filter { $0.kind == .emergency || $0.kind == .police }
    }

    private var doNowFollowUpCards: [AccidentGuidanceCard] {
        guidance.cards.filter { card in
            switch card.kind {
            case .emergency, .police, .disclaimer, .photos, .insurer:
                return false
            case .note:
                return card.id != "brexit-claim"
            default:
                return true
            }
        }
    }

    private func vehiclesStep(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            Text("The vehicle you were driving, then the other vehicle if there was one. UK plates can be looked up for MOT, tax and SORN.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)

            yourDetailsCard(record)

            if record.noOtherVehicle {
                AppSettingsSection("Other vehicles", caption: "Single-vehicle incident — nothing to exchange.") {
                    AppSecondaryButton("There was another vehicle") {
                        record.noOtherVehicle = false
                        AccidentStore.refreshProcessBranch(for: record, profile: profile)
                        AccidentStore.save(record, in: modelContext)
                    }
                }
            } else {
                ForEach(record.otherVehiclesList) { vehicle in
                    otherVehicleCard(vehicle, record: record)
                }

                if record.otherVehiclesList.isEmpty {
                    AppPrimaryButton("Add the other vehicle", systemImage: "car.fill") {
                        _ = AccidentStore.addOtherVehicle(to: record, in: modelContext)
                    }
                    AppSecondaryButton("No other vehicle") {
                        record.noOtherVehicle = true
                        AccidentStore.refreshProcessBranch(for: record, profile: profile)
                        AccidentStore.save(record, in: modelContext)
                    }
                } else {
                    AppSecondaryButton("Add other vehicle") {
                        _ = AccidentStore.addOtherVehicle(to: record, in: modelContext)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func yourDetailsCard(_ record: AccidentRecord) -> some View {
        AppSettingsSection(
            "Your details",
            caption: profile.kind == .caravan
                ? "Usually the tow car, not the caravan. Filed under \(AccidentStore.filingIdentityLine(for: profile))."
                : "Change the plate if you were not in this motorhome. Filed under \(AccidentStore.filingIdentityLine(for: profile))."
        ) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                    Text("Registration")
                        .font(.headline)
                    Text("The vehicle you were driving.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                }

                HStack(alignment: .center, spacing: AppScreenMetrics.smallSpacing) {
                    AppBoundedTextField(
                        placeholder: "e.g. AB12 CDE",
                        text: Binding(
                            get: { record.ownRegistration },
                            set: { newValue in
                                record.ownRegistration = newValue
                                _ = AccidentStore.clearOwnLookupSnapshotIfStale(for: record)
                                AccidentStore.save(record, in: modelContext)
                            }
                        ),
                        keyboard: .asciiCapable
                    )
                    .textInputAutocapitalization(.characters)

                    Button("Look up") {
                        lookupOwnVehicle(on: record)
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(
                        lookingUpOwnVehicle
                            || record.ownRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                if lookingUpOwnVehicle {
                    ProgressView("Looking up vehicle…")
                } else if !record.ownLookupErrorMessage.isEmpty {
                    Text(record.ownLookupErrorMessage)
                        .font(.caption)
                        .foregroundStyle(LyneqoTheme.Status.danger)
                    if record.ownLookupPending {
                        Button("Retry lookup") { lookupOwnVehicle(on: record) }
                            .font(.caption.weight(.semibold))
                    }
                }

                if record.hasOwnLookupSnapshot, !record.ownLookupSnapshotIsStale {
                    labeled("Lookup", record.ownLookupIdentityLine)
                    labeled("MOT", record.ownLookupMotStatus)
                    labeled("Tax", record.ownLookupTaxStatus)
                    if record.ownLookupMarkedForExport {
                        labeled("Export", "Marked for export")
                    }
                    if let checked = record.ownLookupCheckedAt {
                        Text(Formatters.checkedAtCaption(checked))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                }

                Toggle(
                    "Were you towing a caravan or trailer?",
                    isOn: Binding(
                        get: { record.wasTowing },
                        set: {
                            record.wasTowing = $0
                            AccidentStore.refreshProcessBranch(for: record, profile: profile)
                            AccidentStore.save(record, in: modelContext)
                        }
                    )
                )

                AppSecondaryButton("Fill from My Card") {
                    myCardError = nil
                    showMyCardPicker = true
                }

                Text("Copies name, address and phone from Contacts → My Card onto this incident.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)

                if let myCardError {
                    AppWarningBanner(message: myCardError)
                }

                TextField("Your name", text: stringBinding(record, \.ownName))
                    .textContentType(.name)
                TextField("Your phone", text: stringBinding(record, \.ownPhone))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Your address", text: stringBinding(record, \.ownAddress), axis: .vertical)
                    .lineLimit(2...4)
                    .textContentType(.fullStreetAddress)

                TextField("Insurer", text: stringBinding(record, \.ownInsurerName))
                TextField("Policy number", text: stringBinding(record, \.ownInsurancePolicyNumber))
                TextField("Claims phone", text: stringBinding(record, \.ownInsuranceClaimsPhone))
                    .keyboardType(.phonePad)
            }
        }
    }

    private func otherVehicleCard(_ vehicle: AccidentOtherVehicle, record: AccidentRecord) -> some View {
        AppSettingsSection(vehicle.displayRegistration) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                Toggle("Foreign registration", isOn: Binding(
                    get: { vehicle.isForeignRegistration },
                    set: { newValue in
                        vehicle.isForeignRegistration = newValue
                        if newValue {
                            AccidentStore.clearLookupSnapshot(for: vehicle)
                            vehicle.lookupErrorMessage = ""
                        }
                        AccidentStore.refreshRedFlags(for: vehicle)
                        AccidentStore.refreshProcessBranch(for: record, profile: profile)
                        AccidentStore.save(record, in: modelContext)
                    }
                ))

                HStack {
                    TextField(
                        vehicle.isForeignRegistration ? "Registration" : "UK registration",
                        text: Binding(
                            get: { vehicle.registration },
                            set: { newValue in
                                vehicle.registration = newValue
                                if AccidentStore.clearLookupSnapshotIfStale(for: vehicle) {
                                    AccidentStore.refreshProcessBranch(for: record, profile: profile)
                                    AccidentStore.save(record, in: modelContext)
                                }
                            }
                        )
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                    if !vehicle.isForeignRegistration {
                        Button("Look up") {
                            lookup(vehicle, on: record)
                        }
                        .font(.subheadline.weight(.semibold))
                        .disabled(lookingUpVehicleID == vehicle.id)
                    }
                }

                if !vehicle.isForeignRegistration {
                    HStack {
                        Button("Scan plate") {
                            scanningVehicle = vehicle
                            showPlateCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
                            if !showPlateCamera {
                                showPlateLibrary = true
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        Button("Choose plate photo") {
                            scanningVehicle = vehicle
                            showPlateLibrary = true
                        }
                        .font(.caption)
                    }
                    if isScanningPlate && scanningVehicle?.id == vehicle.id {
                        ProgressView("Reading plate…")
                    }
                }

                if vehicle.isForeignRegistration {
                    TextField("Country of registration", text: Binding(
                        get: { vehicle.registrationCountry },
                        set: { vehicle.registrationCountry = $0 }
                    ))
                    TextField("Green Card number", text: Binding(
                        get: { vehicle.greenCardNumber },
                        set: { vehicle.greenCardNumber = $0 }
                    ))
                }

                if lookingUpVehicleID == vehicle.id {
                    ProgressView("Looking up vehicle…")
                } else if !vehicle.lookupErrorMessage.isEmpty {
                    Text(vehicle.lookupErrorMessage)
                        .font(.caption)
                        .foregroundStyle(LyneqoTheme.Status.danger)
                    if vehicle.lookupPending {
                        Button("Retry lookup") { lookup(vehicle, on: record) }
                            .font(.caption.weight(.semibold))
                    }
                }

                if vehicle.hasLookupSnapshot, !vehicle.lookupSnapshotIsStale {
                    labeled("Lookup", [vehicle.lookupMake, vehicle.lookupModel, vehicle.lookupColour].filter { !$0.isEmpty }.joined(separator: " "))
                    if !vehicle.lookupMotStatus.isEmpty {
                        labeled("MOT", vehicle.lookupMotStatus)
                    }
                    if !vehicle.lookupTaxStatus.isEmpty {
                        labeled("Tax", vehicle.lookupTaxStatus)
                    }
                    if let checked = vehicle.lookupCheckedAt {
                        Text(Formatters.checkedAtCaption(checked))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                }

                if !vehicle.redFlags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(vehicle.redFlags) { flag in
                            Label(flag.displayName, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LyneqoTheme.Status.danger)
                        }
                    }
                }

                TextField("Colour you see", text: Binding(
                    get: { vehicle.userConfirmedColour },
                    set: {
                        vehicle.userConfirmedColour = $0
                        AccidentStore.refreshRedFlags(for: vehicle)
                        AccidentStore.save(record, in: modelContext)
                    }
                ))
                TextField("Driver name", text: Binding(get: { vehicle.driverName }, set: { vehicle.driverName = $0 }))
                TextField("Driver phone", text: Binding(get: { vehicle.driverPhone }, set: { vehicle.driverPhone = $0 }))
                    .keyboardType(.phonePad)
                TextField("Driver address", text: Binding(get: { vehicle.driverAddress }, set: { vehicle.driverAddress = $0 }), axis: .vertical)
                    .lineLimit(2...4)

                AccidentDrivingLicencePhotoRow(
                    vehicleID: vehicleID,
                    record: record,
                    vehicle: vehicle
                )

                TextField("Insurer", text: Binding(get: { vehicle.insurerName }, set: { vehicle.insurerName = $0 }))
                TextField("Policy number", text: Binding(get: { vehicle.insurancePolicyNumber }, set: { vehicle.insurancePolicyNumber = $0 }))

                HStack(alignment: .center, spacing: 8) {
                    Toggle("Could not confirm insurance", isOn: Binding(
                        get: { vehicle.redFlags.contains(.suspectedUninsured) },
                        set: { on in
                            var flags = vehicle.redFlags
                            if on {
                                if !flags.contains(.suspectedUninsured) { flags.append(.suspectedUninsured) }
                            } else {
                                flags.removeAll { $0 == .suspectedUninsured }
                            }
                            vehicle.redFlags = flags
                            AccidentStore.refreshProcessBranch(for: record, profile: profile)
                            AccidentStore.save(record, in: modelContext)
                        }
                    ))

                    Button {
                        showAskMIDInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundStyle(AppColors.teal)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Insurance lookup information")
                }

                Button("Remove vehicle", role: .destructive) {
                    AccidentStore.deleteOtherVehicle(vehicle, in: modelContext)
                }
                .font(.subheadline)
            }
        }
    }

    private func photosStep(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            Text("Photograph what you can if it is safe. Photos stay on this device.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)

            Toggle(
                "Were you towing a caravan or trailer?",
                isOn: Binding(
                    get: { record.wasTowing },
                    set: {
                        record.wasTowing = $0
                        AccidentStore.refreshProcessBranch(for: record, profile: profile)
                        AccidentStore.save(record, in: modelContext)
                    }
                )
            )
            .font(.subheadline.weight(.medium))

            AccidentPhotoChecklistSection(
                vehicleID: vehicleID,
                record: record,
                kinds: guidance.photoKinds
            )
        }
    }

    private func detailsStep(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            AppSettingsSection("Weather and conditions") {
                TextField("Weather, light, road surface", text: stringBinding(record, \.weatherNotes), axis: .vertical)
                    .lineLimit(2...4)
            }

            AppSettingsSection("Factual notes", caption: "What happened, without admitting fault.") {
                TextField("Short factual note", text: stringBinding(record, \.factualNotes), axis: .vertical)
                    .lineLimit(3...8)
            }

            if record.jurisdiction.isEuropeOrIreland || record.jurisdiction == .other || record.processBranch == .ukForeignVehicle {
                AppSettingsSection(
                    "Accident statement notes",
                    caption: "Useful for a European Accident Statement. Signing a paper form records agreed facts, not liability."
                ) {
                    TextField("Circumstances both of you might agree", text: stringBinding(record, \.easCircumstancesNotes), axis: .vertical)
                        .lineLimit(3...8)
                    if record.jurisdiction == .france {
                        Link("French constat guidance", destination: AccidentLinks.franceConstat)
                            .font(.subheadline.weight(.semibold))
                    } else if record.jurisdiction.isEuropeOrIreland {
                        Link("Your Europe accident guidance", destination: AccidentLinks.yourEuropeAccident)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            AppSettingsSection(
                "CCTV and video",
                caption: "Ask witnesses if they caught it. Look around for cameras. Lorries and HGVs often have several outward-facing cameras even when they were not involved — if one is nearby, note the plate."
            ) {
                Toggle("Any witness has dashcam, phone video or CCTV?", isOn: boolBinding(record, \.cctvWitnessesMentioned))
                Toggle("Can you see CCTV nearby?", isOn: boolBinding(record, \.cctvNearbyVisible))
                Toggle("Uninvolved lorry or HGV nearby with cameras?", isOn: boolBinding(record, \.cctvNearbyLorry))

                if record.cctvWitnessesMentioned || record.cctvNearbyVisible || record.cctvNearbyLorry {
                    TextField(
                        "Camera location, shop name, or lorry registration",
                        text: stringBinding(record, \.cctvNotes),
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }

            AppSettingsSection("Witnesses") {
                ForEach(record.witnessesList) { witness in
                    VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
                        TextField("Name", text: Binding(get: { witness.name }, set: { witness.name = $0 }))
                        TextField("Phone", text: Binding(get: { witness.phone }, set: { witness.phone = $0 }))
                            .keyboardType(.phonePad)
                        Toggle(
                            "They have video or CCTV",
                            isOn: Binding(
                                get: { witness.hasFootage },
                                set: {
                                    witness.hasFootage = $0
                                    if $0 {
                                        record.cctvWitnessesMentioned = true
                                    }
                                    AccidentStore.save(record, in: modelContext)
                                }
                            )
                        )
                        TextField(
                            witness.hasFootage ? "What footage, and how to get it" : "Notes",
                            text: Binding(get: { witness.notes }, set: { witness.notes = $0 }),
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                        Button("Remove witness", role: .destructive) {
                            AccidentStore.deleteWitness(witness, in: modelContext)
                        }
                        .font(.caption)
                    }
                    if witness.id != record.witnessesList.last?.id {
                        Divider()
                    }
                }
                AppSecondaryButton("Add witness") {
                    _ = AccidentStore.addWitness(to: record, in: modelContext)
                }
            }
        }
    }

    private func reviewStep(_ record: AccidentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.sectionSpacing) {
            AppWarningBanner(message: AccidentGuidance.helperDisclaimer)

            AppSettingsSection("Summary", caption: "Tap a row to go back and change it.") {
                summaryJump("When", Formatters.dateTime(record.occurredAt), to: .scene)
                summaryJump("Where", reviewWhereLine(record), to: .scene)
                summaryJump("Injured", record.anyoneInjured ? "Yes" : "No / not sure", to: .scene)
                summaryJump("Your vehicle", reviewVehicleLine(record), to: .vehicles)
                summaryJump(
                    "Other vehicles",
                    record.noOtherVehicle ? "None — single vehicle" : "\(record.otherVehiclesList.count)",
                    to: .vehicles
                )
                summaryJump("Photos", "\(record.photosList.count)", to: .photos)
                summaryJump("CCTV / video", cctvSummary(record), to: .details)
                summaryJump(
                    "Police",
                    record.policeReported ? (record.policeReference.isEmpty ? "Reported" : record.policeReference) : "Not yet",
                    to: .doNow
                )
            }

            AppSettingsSection("Follow up") {
                Toggle("Told my insurer?", isOn: boolBinding(record, \.insurerNotified))
            }

            if guidance.cards.contains(where: { $0.kind == .police || $0.kind == .emergency }) {
                AppSettingsSection("Still outstanding") {
                    ForEach(guidance.cards.filter { $0.kind == .emergency || $0.kind == .police }) { card in
                        Text(card.title)
                            .font(.subheadline.weight(.semibold))
                        Text(card.body)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSupporting)
                    }
                }
            }

            if record.photosList.isEmpty && record.otherVehiclesList.isEmpty && !record.noOtherVehicle {
                Text("This pack will be thin until you add the other vehicle or photos.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
            }

            AppPrimaryButton("Share incident pack", systemImage: "square.and.arrow.up") {
                exportPack(record)
            }
        }
    }

    private func summaryJump(_ title: String, _ value: String, to destination: AccidentRecorderStep) -> some View {
        Button {
            step = destination
        } label: {
            HStack(alignment: .top) {
                labeled(title, value)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.top, 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(destination.title)")
    }

    private func reviewWhereLine(_ record: AccidentRecord) -> String {
        let place = record.locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if place.isEmpty { return record.jurisdiction.displayName }
        return "\(place) · \(record.jurisdiction.displayName)"
    }

    private func reviewVehicleLine(_ record: AccidentRecord) -> String {
        let plate = record.displayOwnRegistration
        let identity = record.ownLookupIdentityLine
        if plate.isEmpty { return "Not recorded" }
        if record.hasOwnLookupSnapshot, !record.ownLookupSnapshotIsStale, !identity.isEmpty {
            return "\(plate) · \(identity)"
        }
        return plate
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSupporting)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    private func cctvSummary(_ record: AccidentRecord) -> String {
        var parts: [String] = []
        if record.cctvWitnessesMentioned { parts.append("witness footage") }
        if record.cctvNearbyVisible { parts.append("cameras nearby") }
        if record.cctvNearbyLorry { parts.append("lorry cameras") }
        if parts.isEmpty { return "None noted" }
        return parts.joined(separator: ", ")
    }

    private func analyzePlate(_ image: UIImage) {
        isScanningPlate = true
        Task {
            let suggestions = (try? await UKNumberPlateOCR.analyze(image: image)) ?? []
            await MainActor.run {
                isScanningPlate = false
                plateSuggestions = suggestions
                if suggestions.isEmpty {
                    scanningVehicle = nil
                } else if suggestions.count == 1 {
                    applyPlateSuggestion(suggestions[0])
                } else {
                    showPlateSuggestions = true
                }
            }
        }
    }

    private func applyPlateSuggestion(_ suggestion: String) {
        guard let vehicle = scanningVehicle, let record else {
            scanningVehicle = nil
            return
        }
        vehicle.registration = suggestion
        vehicle.isForeignRegistration = false
        AccidentStore.clearLookupSnapshotIfStale(for: vehicle)
        AccidentStore.save(record, in: modelContext)
        scanningVehicle = nil
        plateSuggestions = []
        lookup(vehicle, on: record)
    }

    private func lookupOwnVehicle(on record: AccidentRecord) {
        lookingUpOwnVehicle = true
        Task {
            _ = await AccidentStore.lookupOwnUKPlate(
                record.ownRegistration,
                on: record,
                using: vehicleLookup,
                in: modelContext
            )
            lookingUpOwnVehicle = false
        }
    }

    private func lookup(_ vehicle: AccidentOtherVehicle, on record: AccidentRecord) {
        lookingUpVehicleID = vehicle.id
        Task {
            _ = await AccidentStore.lookupUKPlate(
                vehicle.registration,
                on: vehicle,
                using: vehicleLookup,
                in: modelContext
            )
            AccidentStore.refreshProcessBranch(for: record, profile: profile)
            AccidentStore.save(record, in: modelContext)
            lookingUpVehicleID = nil
        }
    }

    private func exportPack(_ record: AccidentRecord) {
        let photos: [(AccidentPhotoKind, UIImage)] = record.photosList.compactMap { photo in
            guard let image = AccidentPhotoStore.loadImage(for: photo, vehicleID: vehicleID) else { return nil }
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

    private func applyMyCard(_ contact: CNContact, to record: AccidentRecord) {
        let details = MyCardContactMapper.details(from: contact)
        if details.isEmpty {
            myCardError = MyCardContactError.emptyMeCard.errorDescription
            return
        }
        record.ownName = details.name
        record.ownAddress = details.address
        record.ownPhone = details.phone
        AccidentStore.save(record, in: modelContext)
        myCardError = nil
    }

    private func ensureRecord() {
        if let existing {
            record = existing
            AccidentStore.backfillLegacyOwnVehicleIfNeeded(on: existing, from: profile)
            AccidentStore.save(existing, in: modelContext)
            return
        }
        if record == nil {
            let created = AccidentStore.createRecord(for: vehicleID, profile: profile, in: modelContext)
            record = created
        }
        applyLocationIfNeeded()
    }

    private func applyLocationIfNeeded() {
        guard let record, let coordinate = locationCapture.coordinate else { return }
        if locationRefreshRequested {
            locationRefreshRequested = false
            locationDraft = coordinate
            locationDraftCountryCode = nil
            locationNeedsConfirmation = true
            locationSearchError = nil
            locationMapRevision += 1
        } else if !record.hasCoordinate, locationDraft == nil {
            locationDraft = coordinate
            locationDraftCountryCode = nil
            locationNeedsConfirmation = true
            locationMapRevision += 1
        }
    }

    private func displayedCoordinate(for record: AccidentRecord) -> CLLocationCoordinate2D? {
        if let locationDraft {
            return locationDraft
        }
        guard record.hasCoordinate else { return nil }
        return CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
    }

    private func updateLocationDraft(_ coordinate: CLLocationCoordinate2D) {
        locationDraft = coordinate
        locationDraftCountryCode = nil
        locationNeedsConfirmation = true
        locationSearchError = nil
    }

    private func searchLocation(_ record: AccidentRecord) {
        let query = record.locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isSearchingLocation else { return }

        isSearchingLocation = true
        locationSearchError = nil

        Task {
            var request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            if let nearby = displayedCoordinate(for: record) ?? locationCapture.coordinate {
                request.region = MKCoordinateRegion(
                    center: nearby,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }

            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let result = response.mapItems.first else {
                    isSearchingLocation = false
                    locationSearchError = "No matching place was found. Try a postcode, road, town or landmark."
                    return
                }

                locationDraft = result.placemark.coordinate
                locationDraftCountryCode = result.placemark.countryCode
                pinJurisdiction = AccidentJurisdiction.inferred(fromCountryCode: result.placemark.countryCode)
                locationNeedsConfirmation = true
                locationMapRevision += 1
                isSearchingLocation = false

                if let title = result.placemark.title, !title.isEmpty {
                    record.locationDescription = title
                    AccidentStore.save(record, in: modelContext)
                }
            } catch {
                isSearchingLocation = false
                locationSearchError = "The place could not be searched right now. Check your connection or move the pin manually."
            }
        }
    }

    private func confirmLocation(_ record: AccidentRecord) async {
        guard let coordinate = locationDraft else { return }
        isConfirmingLocation = true

        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            .first

        record.latitude = coordinate.latitude
        record.longitude = coordinate.longitude

        let countryCode = placemark?.isoCountryCode ?? locationDraftCountryCode
        if let inferred = AccidentJurisdiction.inferred(fromCountryCode: countryCode) {
            record.jurisdiction = inferred
            pinJurisdiction = inferred
        }
        if let placemark, let address = formattedAddress(from: placemark), !address.isEmpty {
            record.locationDescription = address
        }

        locationDraft = nil
        locationDraftCountryCode = nil
        locationNeedsConfirmation = false
        isConfirmingLocation = false
        AccidentStore.refreshProcessBranch(for: record, profile: profile)
        AccidentStore.save(record, in: modelContext)
    }

    private func formattedAddress(from placemark: CLPlacemark) -> String? {
        let parts = [
            placemark.name,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country
        ]
        let unique = parts.compactMap { value -> String? in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }.reduce(into: [String]()) { result, value in
            if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                result.append(value)
            }
        }
        return unique.isEmpty ? nil : unique.joined(separator: ", ")
    }

    private func move(by delta: Int) {
        if let record {
            if step == .scene, delta > 0, locationNeedsConfirmation {
                Task {
                    await confirmLocation(record)
                    AccidentStore.refreshProcessBranch(for: record, profile: profile)
                    AccidentStore.save(record, in: modelContext)
                    advanceStep(by: delta)
                }
                return
            }
            AccidentStore.refreshProcessBranch(for: record, profile: profile)
            AccidentStore.save(record, in: modelContext)
            Task {
                await AccidentStore.retryPendingLookups(on: record, using: vehicleLookup, in: modelContext)
            }
        }
        advanceStep(by: delta)
    }

    private func advanceStep(by delta: Int) {
        let all = AccidentRecorderStep.allCases
        guard let index = all.firstIndex(of: step) else { return }
        let next = index + delta
        guard all.indices.contains(next) else { return }
        step = all[next]
    }

    private func jurisdictionBinding(_ record: AccidentRecord) -> Binding<AccidentJurisdiction> {
        Binding(
            get: { record.jurisdiction },
            set: {
                record.jurisdiction = $0
                AccidentStore.refreshProcessBranch(for: record, profile: profile)
                AccidentStore.save(record, in: modelContext)
            }
        )
    }

    private func occurredBinding(_ record: AccidentRecord) -> Binding<Date> {
        Binding(
            get: { record.occurredAt },
            set: {
                record.occurredAt = $0
                AccidentStore.save(record, in: modelContext)
            }
        )
    }

    private func boolBinding(_ record: AccidentRecord, _ keyPath: ReferenceWritableKeyPath<AccidentRecord, Bool>) -> Binding<Bool> {
        Binding(
            get: { record[keyPath: keyPath] },
            set: {
                record[keyPath: keyPath] = $0
                AccidentStore.refreshProcessBranch(for: record, profile: profile)
                AccidentStore.save(record, in: modelContext)
            }
        )
    }

    private func stringBinding(_ record: AccidentRecord, _ keyPath: ReferenceWritableKeyPath<AccidentRecord, String>) -> Binding<String> {
        Binding(
            get: { record[keyPath: keyPath] },
            set: {
                record[keyPath: keyPath] = $0
                AccidentStore.save(record, in: modelContext)
            }
        )
    }
}

private struct AccidentLocationMap: View {
    @Binding var coordinate: CLLocationCoordinate2D

    private static let defaultSpan = 0.006
    private static let minSpan = 0.0004
    private static let maxSpan = 0.4

    @State private var cameraPosition: MapCameraPosition
    @State private var spanDelta: Double

    init(coordinate: Binding<CLLocationCoordinate2D>) {
        _coordinate = coordinate
        let span = Self.defaultSpan
        _spanDelta = State(initialValue: span)
        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate.wrappedValue,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
            )
        )
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                Annotation("Accident location", coordinate: coordinate, anchor: .bottom) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 38))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, LyneqoTheme.Status.danger)
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(
                                minimumDistance: 0,
                                coordinateSpace: .named("accidentLocationMap")
                            )
                            .onChanged { value in
                                if let moved = proxy.convert(
                                    value.location,
                                    from: .named("accidentLocationMap")
                                ) {
                                    coordinate = moved
                                }
                            }
                        )
                        .accessibilityLabel("Accident location pin")
                        .accessibilityHint("Drag to correct the accident location")
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .coordinateSpace(name: "accidentLocationMap")
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: AppScreenMetrics.smallSpacing) {
                    Text("Drag pin to adjust")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                        .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        Button {
                            zoom(by: 0.5)
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("Zoom in")

                        Divider()
                            .frame(width: 28)

                        Button {
                            zoom(by: 2.0)
                        } label: {
                            Image(systemName: "minus")
                                .font(.body.weight(.semibold))
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("Zoom out")
                    }
                    .foregroundStyle(LyneqoTheme.deepNavy)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(8)
            }
        }
    }

    private func zoom(by factor: Double) {
        let next = min(Self.maxSpan, max(Self.minSpan, spanDelta * factor))
        spanDelta = next
        withAnimation(.easeInOut(duration: 0.2)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: next, longitudeDelta: next)
                )
            )
        }
    }
}

private struct IdentifiedPDF: Identifiable {
    let id = UUID()
    let data: Data
}

struct AccidentStepIndicator: View {
    @Binding var step: AccidentRecorderStep

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(AccidentRecorderStep.allCases) { item in
                    Button {
                        step = item
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(item.rawValue). \(item.title)")
                                .font(.caption.weight(step == item ? .semibold : .regular))
                                .foregroundStyle(step == item ? Color.accentColor : AppColors.textSupporting)
                            Capsule()
                                .fill(step == item ? Color.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct AccidentGuidanceCardView: View {
    let card: AccidentGuidanceCard
    let onOpen: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.smallSpacing) {
            HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                    Text(card.body)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let number = card.callNumber, let url = URL(string: "tel://\(number)") {
                Button("Call \(number)") {
                    onOpen(url)
                }
                .font(.subheadline.weight(.semibold))
            }
            if let link = card.linkURL, let title = card.linkTitle {
                Button(title) {
                    onOpen(link)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(AppScreenMetrics.cardInteriorPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LyneqoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .overlay {
            if card.kind == .emergency || card.kind == .police {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(LyneqoTheme.Status.danger.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var iconName: String {
        switch card.kind {
        case .emergency: return "phone.fill"
        case .police: return "exclamationmark.triangle.fill"
        case .insurer: return "shield.fill"
        case .photos: return "camera.fill"
        case .eas: return "doc.text.fill"
        case .safety: return "light.beacon.max.fill"
        case .disclaimer: return "info.circle.fill"
        case .exchange: return "person.2.fill"
        case .lookup: return "magnifyingglass"
        case .note: return "text.alignleft"
        }
    }

    private var iconColor: Color {
        switch card.kind {
        case .emergency, .police: return LyneqoTheme.Status.danger
        case .insurer, .eas: return AppColors.blue
        default: return Color.accentColor
        }
    }
}

@MainActor
final class AccidentLocationCapture: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()
    private var didRequest = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestIfNeeded() {
        guard !didRequest else { return }
        didRequest = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            authorizationDenied = true
        }
    }

    func requestCurrentLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            manager.requestLocation()
        default:
            authorizationDenied = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
