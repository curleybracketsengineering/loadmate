import XCTest
@testable import loadMate3

final class CRiSVINChipOCRTests: XCTestCase {
    func testVINFromRawQRPayload() {
        XCTAssertEqual(
            CRiSVINChipOCR.vinFromQRPayload("SGA12345BY8123456"),
            "SGA12345BY8123456"
        )
    }

    func testVINFromQRURLQuery() {
        XCTAssertEqual(
            CRiSVINChipOCR.vinFromQRPayload("https://www.cris.co.uk/check?vin=SGBT001SW9123456"),
            "SGBT001SW9123456"
        )
    }

    func testVINFromQRURLPath() {
        XCTAssertEqual(
            CRiSVINChipOCR.vinFromQRPayload("https://example.com/asset/SGBT001SW9123456"),
            "SGBT001SW9123456"
        )
    }

    func testVINFromEmbeddedTextInQR() {
        XCTAssertEqual(
            CRiSVINChipOCR.vinFromQRPayload("CRiS protected vehicle VIN SGA12345BY8123456"),
            "SGA12345BY8123456"
        )
    }

    func testSuggestionsPreferQROverOCR() {
        let suggestions = CRiSVINChipOCR.suggestions(
            fromQRPayloads: ["https://check.example/?vin=SGBT001SW9123456"],
            ocrLines: ["VIN SGA12345BY8123456", "CRIS"]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "SGBT001SW9123456")
        XCTAssertEqual(suggestions.source, .qrCode)
        XCTAssertTrue(suggestions.hasAnySuggestion)
    }

    func testSuggestionsFallBackToOCRWhenQRHasNoVIN() {
        let suggestions = CRiSVINChipOCR.suggestions(
            fromQRPayloads: ["https://www.cris.co.uk/vin-chip"],
            ocrLines: ["VIN CHIP", "CHASSIS NO SGA12345BY8123456"]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "SGA12345BY8123456")
        XCTAssertEqual(suggestions.source, .ocrText)
    }

    func testSuggestionsEmptyWhenNothingRecognised() {
        let suggestions = CRiSVINChipOCR.suggestions(
            fromQRPayloads: [],
            ocrLines: ["HELLO", "WORLD"]
        )

        XCTAssertNil(suggestions.vinChassisNumber)
        XCTAssertFalse(suggestions.hasAnySuggestion)
        XCTAssertFalse(suggestions.confidenceNotes.isEmpty)
    }
}
