import XCTest
@testable import loadMate3

final class AccidentGuidanceTests: XCTestCase {
    func testUKStandardDoesNotForcePoliceWhenDetailsExchanged() {
        var input = AccidentGuidanceInput()
        input.jurisdiction = .unitedKingdom
        input.detailsExchanged = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertFalse(result.shouldCallEmergencyNow)
        XCTAssertFalse(result.shouldReportPolice)
        XCTAssertEqual(result.emergencyNumber, "999")
        XCTAssertEqual(result.processBranch, .ukStandard)
        XCTAssertTrue(result.shouldNotifyInsurer)
        XCTAssertTrue(result.cards.contains(where: { $0.kind == .disclaimer }))
        XCTAssertTrue(result.cards.contains(where: { $0.kind == .insurer }))
    }

    func testInjuryCallsEmergencyAndPolice() {
        var input = AccidentGuidanceInput()
        input.anyoneInjured = true
        input.detailsExchanged = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertTrue(result.shouldCallEmergencyNow)
        XCTAssertTrue(result.shouldReportPolice)
        XCTAssertEqual(result.emergencyNumber, "999")
        XCTAssertTrue(result.cards.contains(where: { $0.callNumber == "999" }))
        XCTAssertEqual(result.processBranch, .ukPoliceFlag)
    }

    func testHitAndRunIsEmergency() {
        var input = AccidentGuidanceInput()
        input.hitAndRun = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertTrue(result.shouldCallEmergencyNow)
        XCTAssertTrue(result.cards.contains(where: { $0.kind == .emergency && $0.callNumber == "999" }))
        XCTAssertEqual(result.processBranch, .ukPoliceFlag)
    }

    func testInvalidMOTFlagsPoliceNot999() {
        var input = AccidentGuidanceInput()
        input.detailsExchanged = true
        input.redFlags = [.invalidMOT]

        let result = AccidentGuidance.evaluate(input)
        XCTAssertFalse(result.shouldCallEmergencyNow)
        XCTAssertTrue(result.shouldReportPolice)
        XCTAssertEqual(result.processBranch, .ukPoliceFlag)
        XCTAssertEqual(result.policeNumber, "101")
        XCTAssertTrue(result.cards.contains(where: { $0.id == "mot" && $0.callNumber == "101" }))
        XCTAssertTrue(result.cards.contains(where: {
            $0.id == "mot" && $0.body.localizedCaseInsensitiveContains("101 or online")
        }))
        XCTAssertFalse(result.cards.contains(where: { $0.kind == .emergency }))
    }

    func testSORNIsStrongerThanMOTAlone() {
        var input = AccidentGuidanceInput()
        input.detailsExchanged = true
        input.redFlags = [.sorn]

        let result = AccidentGuidance.evaluate(input)
        XCTAssertTrue(result.shouldReportPolice)
        XCTAssertTrue(result.cards.contains(where: { $0.id == "sorn" && $0.callNumber == "101" }))
        XCTAssertTrue(result.cards.contains(where: {
            $0.id == "sorn" && $0.body.localizedCaseInsensitiveContains("101 or online")
        }))
        XCTAssertTrue(result.cards.contains(where: { $0.body.localizedCaseInsensitiveContains("uninsured") }))
    }

    func testExpiredMOTAndSORNUsesCombinedPoliceCard() {
        var input = AccidentGuidanceInput()
        input.detailsExchanged = true
        input.redFlags = [.invalidMOT, .sorn]

        let result = AccidentGuidance.evaluate(input)
        XCTAssertFalse(result.shouldCallEmergencyNow)
        XCTAssertTrue(result.shouldReportPolice)
        XCTAssertEqual(result.processBranch, .ukPoliceFlag)
        XCTAssertEqual(result.policeNumber, "101")
        XCTAssertTrue(result.cards.contains(where: {
            $0.id == "mot-sorn"
                && $0.callNumber == "101"
                && $0.body.localizedCaseInsensitiveContains("101 or online")
        }))
        XCTAssertFalse(result.cards.contains(where: { $0.id == "mot" }))
        XCTAssertFalse(result.cards.contains(where: { $0.id == "sorn" }))
    }

    func testForeignVehicleInUKUsesMIBBranch() {
        var input = AccidentGuidanceInput()
        input.detailsExchanged = true
        input.otherVehicleIsForeign = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertEqual(result.processBranch, .ukForeignVehicle)
        XCTAssertFalse(result.shouldReportPolice)
        XCTAssertTrue(result.cards.contains(where: { $0.id == "foreign-uk" }))
        XCTAssertEqual(result.cards.first(where: { $0.id == "foreign-uk" })?.linkURL, AccidentLinks.mibForeignInUK)
    }

    func testFranceUsesPaperEASAnd112() {
        var input = AccidentGuidanceInput()
        input.jurisdiction = .france
        input.detailsExchanged = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertEqual(result.emergencyNumber, "112")
        XCTAssertEqual(result.processBranch, .francePaperEAS)
        XCTAssertTrue(result.cards.contains(where: { $0.id == "france-eas" }))
        XCTAssertTrue(result.cards.contains(where: { $0.id == "hivis" }))
        XCTAssertTrue(result.cards.contains(where: { $0.id == "brexit-claim" }))
        XCTAssertFalse(result.shouldCallEmergencyNow)
    }

    func testFranceInjuryCalls112AndPolice() {
        var input = AccidentGuidanceInput()
        input.jurisdiction = .france
        input.anyoneInjured = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertTrue(result.shouldCallEmergencyNow)
        XCTAssertTrue(result.shouldReportPolice)
        XCTAssertTrue(result.cards.contains(where: { $0.callNumber == "112" }))
    }

    func testGenericEUUsesEAS() {
        var input = AccidentGuidanceInput()
        input.jurisdiction = .europeanUnion
        input.detailsExchanged = true

        let result = AccidentGuidance.evaluate(input)
        XCTAssertEqual(result.processBranch, .europeEAS)
        XCTAssertEqual(result.emergencyNumber, "112")
        XCTAssertTrue(result.cards.contains(where: { $0.id == "eas" }))
    }

    func testSpainAndGermanyUseEuropeBranch() {
        for jurisdiction in [AccidentJurisdiction.spain, .germany, .ireland] {
            var input = AccidentGuidanceInput()
            input.jurisdiction = jurisdiction
            XCTAssertEqual(AccidentGuidance.evaluate(input).processBranch, .europeEAS)
        }
    }

    func testOtherAbroadBranch() {
        var input = AccidentGuidanceInput()
        input.jurisdiction = .other

        let result = AccidentGuidance.evaluate(input)
        XCTAssertEqual(result.processBranch, .otherAbroad)
        XCTAssertEqual(result.emergencyNumber, "112")
        XCTAssertTrue(result.cards.contains(where: { $0.id == "abroad" }))
    }

    func testMapCountryCodeInfersGuidanceJurisdiction() {
        XCTAssertEqual(AccidentJurisdiction.inferred(fromCountryCode: "GB"), .unitedKingdom)
        XCTAssertEqual(AccidentJurisdiction.inferred(fromCountryCode: "FR"), .france)
        XCTAssertEqual(AccidentJurisdiction.inferred(fromCountryCode: "ES"), .spain)
        XCTAssertEqual(AccidentJurisdiction.inferred(fromCountryCode: "NL"), .europeanUnion)
        XCTAssertEqual(AccidentJurisdiction.inferred(fromCountryCode: "US"), .other)
        XCTAssertNil(AccidentJurisdiction.inferred(fromCountryCode: nil))
    }

    func testCaravanPhotoKindsIncludeHitch() {
        var input = AccidentGuidanceInput()
        input.vehicleKind = .caravan
        let kinds = AccidentGuidance.photoKinds(for: input)
        XCTAssertTrue(kinds.contains(.hitch))
        XCTAssertTrue(kinds.contains(.trailer))
        XCTAssertTrue(kinds.contains(.positions))
        XCTAssertTrue(kinds.contains(.plate))
    }

    func testMotorhomeWithoutTowOmitsHitch() {
        var input = AccidentGuidanceInput()
        input.vehicleKind = .motorhome
        input.hasTowOrTrailer = false
        let kinds = AccidentGuidance.photoKinds(for: input)
        XCTAssertFalse(kinds.contains(.hitch))
        XCTAssertFalse(kinds.contains(.trailer))
    }

    func testMotorhomeWithTowIncludesHitch() {
        var input = AccidentGuidanceInput()
        input.vehicleKind = .motorhome
        input.hasTowOrTrailer = true
        XCTAssertTrue(AccidentGuidance.photoKinds(for: input).contains(.hitch))
    }

    func testLookupFlagsDetectSORNCaseInsensitive() {
        XCTAssertTrue(AccidentLookupFlags.isSORN(taxStatus: "SORN"))
        XCTAssertTrue(AccidentLookupFlags.isSORN(taxStatus: "sorn"))
        XCTAssertFalse(AccidentLookupFlags.isUntaxed(taxStatus: "SORN"))
    }

    func testLookupFlagsDetectUntaxedAndValidTax() {
        XCTAssertTrue(AccidentLookupFlags.isUntaxed(taxStatus: "Untaxed"))
        XCTAssertFalse(AccidentLookupFlags.isUntaxed(taxStatus: "Taxed"))
        XCTAssertFalse(AccidentLookupFlags.isSORN(taxStatus: "Taxed"))
    }

    func testLookupFlagsDetectInvalidMOTFromStatusAndExpiry() {
        XCTAssertTrue(AccidentLookupFlags.isInvalidMOT(motStatus: "Not valid", motExpiryDate: nil))
        XCTAssertTrue(AccidentLookupFlags.isInvalidMOT(motStatus: "invalid", motExpiryDate: nil))
        XCTAssertFalse(AccidentLookupFlags.isInvalidMOT(motStatus: "valid", motExpiryDate: nil))
        XCTAssertFalse(AccidentLookupFlags.isInvalidMOT(motStatus: "Valid", motExpiryDate: nil))

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(AccidentLookupFlags.isInvalidMOT(motStatus: "valid", motExpiryDate: yesterday))
        XCTAssertFalse(AccidentLookupFlags.isInvalidMOT(motStatus: "valid", motExpiryDate: tomorrow))
        XCTAssertFalse(AccidentLookupFlags.isInvalidMOT(motStatus: "No details held by DVLA", motExpiryDate: nil))
    }

    func testLookupFlagsDetectExportAndMismatch() {
        let flags = AccidentLookupFlags.flags(
            motStatus: "valid",
            motExpiryDate: nil,
            taxStatus: "Taxed",
            markedForExport: true,
            lookupMake: "FORD",
            lookupColour: "BLUE",
            expectedMake: "VAUXHALL",
            expectedColour: "BLUE"
        )
        XCTAssertTrue(flags.contains(.markedForExport))
        XCTAssertTrue(flags.contains(.plateMismatch))
        XCTAssertFalse(flags.contains(.invalidMOT))
    }

    func testLookupResultConvenienceMatchesStoredFlags() {
        let result = VehicleLookupResult(
            registration: "AB12CDE",
            displayRegistration: "AB12 CDE",
            make: "FORD",
            model: "TRANSIT",
            colour: "WHITE",
            fuelType: nil,
            vehicleType: nil,
            yearOfManufacture: nil,
            monthOfFirstRegistration: nil,
            engineCapacityCc: nil,
            co2EmissionsGPerKm: nil,
            latestOdometerMiles: nil,
            taxStatus: "SORN",
            taxDueDate: nil,
            motStatus: "Not valid",
            motExpiryDate: nil,
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
        let flags = AccidentLookupFlags.flags(from: result)
        XCTAssertTrue(flags.contains(.sorn))
        XCTAssertTrue(flags.contains(.invalidMOT))
    }

    func testHelperCopyIsNotLegalAdvice() {
        XCTAssertTrue(AccidentGuidance.helperDisclaimer.localizedCaseInsensitiveContains("not legal advice"))
        XCTAssertTrue(AccidentGuidance.helperDisclaimer.localizedCaseInsensitiveContains("insurer"))
    }
}
