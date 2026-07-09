import XCTest
@testable import loadMate3

final class TyreSidewallOCRTests: XCTestCase {
    func testSuggestionsParseCommonSidewallFields() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        let suggestions = TyreSidewallOCR.suggestions(
            from: [
                "MICHELIN AGILIS CROSSCLIMATE",
                "225/75 R16C",
                "121/120R",
                "1221"
            ],
            now: now
        )

        XCTAssertEqual(suggestions.manufacturer, "Michelin")
        XCTAssertEqual(suggestions.modelName, "Agilis Crossclimate")
        XCTAssertEqual(suggestions.tyreSize, "225/75 R16C")
        XCTAssertEqual(suggestions.loadIndex, "121/120")
        XCTAssertEqual(suggestions.speedRating, "R")
        XCTAssertEqual(suggestions.dateCode, "1221")
    }

    func testSuggestionsIgnoreInvalidFutureDateCode() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        let suggestions = TyreSidewallOCR.suggestions(
            from: [
                "GOODYEAR",
                "4028",
                "215/70R15"
            ],
            now: now
        )

        XCTAssertEqual(suggestions.manufacturer, "Goodyear")
        XCTAssertEqual(suggestions.tyreSize, "215/70 R15")
        XCTAssertNil(suggestions.dateCode)
    }

    func testSuggestionsParseCampingTyreVariantAndNoise() {
        let suggestions = TyreSidewallOCR.suggestions(
            from: [
                "CONTINENTAL VANCONTACT CAMPER",
                "CP 215/75R16CP",
                "116Q EXTRA LOAD"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Continental")
        XCTAssertEqual(suggestions.modelName, "Vancontact Camper")
        XCTAssertEqual(suggestions.tyreSize, "215/75 R16CP")
        XCTAssertEqual(suggestions.loadIndex, "116")
        XCTAssertEqual(suggestions.speedRating, "Q")
    }

    func testSuggestionsParseCommercialRimFormat() {
        let suggestions = TyreSidewallOCR.suggestions(
            from: [
                "HANKOOK VANTRA LT",
                "195R14C",
                "106/104R"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Hankook")
        XCTAssertEqual(suggestions.modelName, "Vantra Lt")
        XCTAssertEqual(suggestions.tyreSize, "195 R14C")
        XCTAssertEqual(suggestions.loadIndex, "106/104")
        XCTAssertEqual(suggestions.speedRating, "R")
    }

    func testSuggestionsParseLightTruckPrefix() {
        let suggestions = TyreSidewallOCR.suggestions(
            from: [
                "BFGOODRICH ALL TERRAIN T/A",
                "LT225/75R16",
                "115/112S"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Bfgoodrich")
        XCTAssertEqual(suggestions.tyreSize, "LT 225/75 R16")
        XCTAssertEqual(suggestions.loadIndex, "115/112")
        XCTAssertEqual(suggestions.speedRating, "S")
    }

    func testSuggestionsReturnNoisyFallbackWhenNothingUsefulFound() {
        let suggestions = TyreSidewallOCR.suggestions(from: ["ABC", "HELLO", "123456"])

        XCTAssertFalse(suggestions.hasAnySuggestion)
        XCTAssertFalse(suggestions.confidenceNotes.isEmpty)
    }
}
