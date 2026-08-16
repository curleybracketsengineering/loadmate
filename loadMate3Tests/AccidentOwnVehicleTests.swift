import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class AccidentOwnVehicleTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try LoadMateModelContainer.makePreview()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testCreateRecordPrefillsOwnVehicleFromProfile() {
        let profile = motorhomeProfile()
        let record = AccidentStore.createRecord(for: profile.id, profile: profile, in: context)

        XCTAssertEqual(record.ownRegistration, "S666SEM")
        XCTAssertEqual(record.ownInsurerName, "Profile Insurer")
        XCTAssertEqual(record.ownInsurancePolicyNumber, "POL-1")
        XCTAssertEqual(record.ownInsuranceClaimsPhone, "0800 111")
    }

    func testCreateRecordPrefillsTowingForCaravanOnly() {
        let caravan = VehicleProfile(name: "Van", kind: .caravan)
        context.insert(caravan)
        let caravanRecord = AccidentStore.createRecord(for: caravan.id, profile: caravan, in: context)
        XCTAssertTrue(caravanRecord.wasTowing)

        let motorhome = motorhomeProfile()
        let motorhomeRecord = AccidentStore.createRecord(for: motorhome.id, profile: motorhome, in: context)
        XCTAssertFalse(motorhomeRecord.wasTowing)
    }

    func testPrefillDoesNotOverwriteEditedOwnVehicle() {
        let profile = motorhomeProfile()
        let record = AccidentStore.createRecord(for: profile.id, profile: profile, in: context)
        record.ownRegistration = "AB12CDE"
        record.ownInsurerName = "Tow Car Cover"

        AccidentStore.prefillOwnVehicle(on: record, from: profile)

        XCTAssertEqual(record.ownRegistration, "AB12CDE")
        XCTAssertEqual(record.ownInsurerName, "Tow Car Cover")
        XCTAssertEqual(profile.registrationMark, "S666SEM")
        XCTAssertEqual(profile.insuranceProviderName, "Profile Insurer")
    }

    func testLegacyBackfillOnlyWhenOwnVehicleUnset() {
        let profile = motorhomeProfile()
        let record = AccidentStore.createRecord(for: profile.id, in: context)
        XCTAssertEqual(record.ownRegistration, "")

        AccidentStore.backfillLegacyOwnVehicleIfNeeded(on: record, from: profile)
        XCTAssertEqual(record.ownRegistration, "S666SEM")
        XCTAssertEqual(record.ownInsurerName, "Profile Insurer")

        record.ownRegistration = "AB12CDE"
        record.ownInsurerName = ""
        AccidentStore.backfillLegacyOwnVehicleIfNeeded(on: record, from: profile)
        XCTAssertEqual(record.ownRegistration, "AB12CDE")
        XCTAssertEqual(record.ownInsurerName, "")
    }

    func testOwnLookupDoesNotWriteVehicleProfile() async {
        let profile = motorhomeProfile()
        profile.manufacturer = "Swift"
        let record = AccidentStore.createRecord(for: profile.id, profile: profile, in: context)
        record.ownRegistration = "AB12CDE"

        let stub = StubVehicleLookupProvider(result: Self.makeLookup(taxStatus: "SORN"))
        let result = await AccidentStore.lookupOwnUKPlate(
            "AB12CDE",
            on: record,
            using: stub,
            in: context
        )

        XCTAssertEqual(result, .success(stub.result))
        XCTAssertEqual(record.ownRegistration, "AB12 CDE")
        XCTAssertEqual(record.ownLookupMake, "FORD")
        XCTAssertEqual(record.ownLookupTaxStatus, "SORN")
        XCTAssertTrue(record.hasOwnLookupSnapshot)
        XCTAssertEqual(profile.registrationMark, "S666SEM")
        XCTAssertEqual(profile.manufacturer, "Swift")
        XCTAssertEqual(profile.insuranceProviderName, "Profile Insurer")
    }

    func testOwnSORNLookupDoesNotRaisePoliceProcessBranch() async {
        let profile = motorhomeProfile()
        let record = AccidentStore.createRecord(for: profile.id, profile: profile, in: context)
        record.detailsExchanged = true
        record.ownRegistration = "AB12CDE"

        let stub = StubVehicleLookupProvider(result: Self.makeLookup(taxStatus: "SORN"))
        _ = await AccidentStore.lookupOwnUKPlate("AB12CDE", on: record, using: stub, in: context)
        AccidentStore.refreshProcessBranch(for: record, profile: profile)

        XCTAssertEqual(record.ownLookupTaxStatus, "SORN")
        XCTAssertEqual(record.processBranch, .ukStandard)
        XCTAssertFalse(AccidentStore.combinedRedFlags(on: record).contains(.sorn))
    }

    func testStaleOwnLookupSnapshotIsCleared() {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        AccidentStore.applyOwnLookup(Self.makeLookup(), to: record)
        XCTAssertTrue(record.hasOwnLookupSnapshot)

        record.ownRegistration = "XY99ZZZ"
        XCTAssertTrue(record.ownLookupSnapshotIsStale)
        XCTAssertTrue(AccidentStore.clearOwnLookupSnapshotIfStale(for: record))
        XCTAssertFalse(record.hasOwnLookupSnapshot)
        XCTAssertEqual(record.ownLookupMake, "")
    }

    func testSharePackUsesIncidentOwnVehicleNotLiveProfile() {
        let profile = motorhomeProfile()
        let record = AccidentStore.createRecord(for: profile.id, profile: profile, in: context)
        record.ownRegistration = "AB12CDE"
        record.ownInsurerName = "Tow Car Cover"
        record.ownInsurancePolicyNumber = "TOW-9"
        AccidentStore.applyOwnLookup(Self.makeLookup(), to: record)

        profile.registrationMark = "XX99YYY"
        profile.insuranceProviderName = "Changed Insurer"

        let input = AccidentEvidencePackBuilder.makeInput(record: record, profile: profile, photoImages: [])
        let lines = AccidentEvidencePackBuilder.ownVehicleLines(from: input)

        XCTAssertTrue(lines.contains("Registration: AB12 CDE"))
        XCTAssertTrue(lines.contains("Lookup: FORD FOCUS BLUE"))
        XCTAssertTrue(lines.contains("Insurer: Tow Car Cover"))
        XCTAssertTrue(lines.contains("Policy: TOW-9"))
        XCTAssertFalse(lines.contains(where: { $0.contains("XX99") }))
        XCTAssertFalse(lines.contains(where: { $0.contains("Changed Insurer") }))
        XCTAssertEqual(input.filingIdentity, "Test Motorhome (motorhome)")
    }

    func testLegacyExportFallsBackToProfileWhenOwnVehicleUnset() {
        let profile = motorhomeProfile()
        let record = AccidentStore.createRecord(for: profile.id, in: context)

        let input = AccidentEvidencePackBuilder.makeInput(record: record, profile: profile, photoImages: [])
        let lines = AccidentEvidencePackBuilder.ownVehicleLines(from: input)

        XCTAssertTrue(lines.contains("Registration: S666 SEM"))
        XCTAssertTrue(lines.contains("Insurer: Profile Insurer"))
    }

    func testCaravanFilingIdentityIncludesCRIS() {
        let profile = VehicleProfile(name: "Swift Conqueror", kind: .caravan)
        profile.vinChassisNumber = "CRIS123"
        XCTAssertEqual(
            AccidentStore.filingIdentityLine(for: profile),
            "Swift Conqueror (caravan) · CRiS / VIN CRIS123"
        )
    }

    func testPendingOwnLookupOnNetworkError() async {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        record.ownRegistration = "AB12CDE"
        let stub = StubVehicleLookupProvider(result: Self.makeLookup(), error: VehicleLookupError.noNetwork)

        let result = await AccidentStore.lookupOwnUKPlate(
            "AB12CDE",
            on: record,
            using: stub,
            in: context
        )

        XCTAssertEqual(result, .failure(.noNetwork))
        XCTAssertTrue(record.ownLookupPending)
        XCTAssertFalse(record.ownLookupErrorMessage.isEmpty)
    }

    private func motorhomeProfile() -> VehicleProfile {
        let profile = VehicleProfile(name: "Test Motorhome", kind: .motorhome)
        profile.registrationMark = "S666SEM"
        profile.insuranceProviderName = "Profile Insurer"
        profile.insurancePolicyNumber = "POL-1"
        profile.insuranceClaimsPhone = "0800 111"
        context.insert(profile)
        return profile
    }

    private static func makeLookup(taxStatus: String = "taxed") -> VehicleLookupResult {
        VehicleLookupResult(
            registration: "AB12CDE",
            displayRegistration: "AB12 CDE",
            make: "FORD",
            model: "FOCUS",
            colour: "BLUE",
            fuelType: nil,
            vehicleType: nil,
            yearOfManufacture: nil,
            monthOfFirstRegistration: nil,
            engineCapacityCc: nil,
            co2EmissionsGPerKm: nil,
            latestOdometerMiles: nil,
            taxStatus: taxStatus,
            taxDueDate: nil,
            motStatus: "valid",
            motExpiryDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            motDaysRemaining: nil,
            lastMotResult: nil,
            lastMotDate: nil,
            firstMotDue: nil,
            totalMotTests: nil,
            motPassRate: nil,
            imminentMot: nil,
            markedForExport: false,
            ulezCompliant: nil,
            checkedAt: Date()
        )
    }
}
