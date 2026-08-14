import XCTest
@testable import loadMate3

final class UKNumberPlateOCRTests: XCTestCase {
    func testExtractsModernUKPlateFromSingleLine() {
        XCTAssertEqual(UKNumberPlateOCR.suggestions(from: ["AB12 CDE"]), ["AB12 CDE"])
    }

    func testJoinsSplitTokens() {
        XCTAssertEqual(UKNumberPlateOCR.suggestions(from: ["AB12", "CDE"]), ["AB12 CDE"])
    }

    func testIgnoresJunkAndDeduplicates() {
        let suggestions = UKNumberPlateOCR.suggestions(from: [
            "HELLO",
            "123456",
            "AB12 CDE",
            "ab12cde"
        ])
        XCTAssertEqual(suggestions, ["AB12 CDE"])
    }

    func testAcceptsPrefixStylePlate() {
        XCTAssertEqual(UKNumberPlateOCR.suggestions(from: ["A123 BCD"]), ["A123 BCD"])
    }
}
