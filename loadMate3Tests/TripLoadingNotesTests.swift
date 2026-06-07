import XCTest
@testable import loadMate3

final class TripLoadingNotesTests: XCTestCase {
    func testCaravanHasLoadingNotesWhenAnyFieldSet() {
        let trip = TestFixtures.trip(name: "Beach")
        let profile = TestFixtures.caravanProfile()

        XCTAssertFalse(trip.hasLoadingNotes(for: .caravan))

        trip.measuredNoseWeightKg = 92
        XCTAssertTrue(trip.hasLoadingNotes(for: .caravan))

        trip.measuredNoseWeightKg = 0
        trip.towingExperience = .excellent
        XCTAssertTrue(trip.hasLoadingNotes(for: .caravan))

        trip.towingExperience = .notSet
        trip.tripNotes = "  Awning packed  "
        XCTAssertTrue(trip.hasLoadingNotes(for: .caravan))
    }

    func testMotorhomeHasLoadingNotesOnlyForTripNotes() {
        let trip = TestFixtures.trip(name: "Europe")

        XCTAssertFalse(trip.hasLoadingNotes(for: .motorhome))

        trip.measuredNoseWeightKg = 80
        trip.towingExperience = .good
        XCTAssertFalse(trip.hasLoadingNotes(for: .motorhome))

        trip.tripNotes = "Rear feels heavy with full fresh water."
        XCTAssertTrue(trip.hasLoadingNotes(for: .motorhome))
    }

    func testCaravanLoadingNotesSummaryBuildsCombinedLine() {
        let trip = TestFixtures.trip(name: "Beach")
        trip.measuredNoseWeightKg = 92
        trip.towingExperience = .excellent
        trip.tripNotes = "Water tanks full"

        let summary = trip.loadingNotesSummary(for: .caravan)

        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.contains("Nose:") == true)
        XCTAssertTrue(summary?.contains("Towing:") == true)
        XCTAssertTrue(summary?.contains("Water tanks full") == true)
    }

    func testMotorhomeLoadingNotesSummaryUsesNotesOnly() {
        let trip = TestFixtures.trip(name: "Weekend")
        trip.tripNotes = "Blocks on driver side"

        XCTAssertEqual(trip.loadingNotesSummary(for: .motorhome), "Blocks on driver side")
    }

    func testTowingExperiencePickerCasesExcludeNotSet() {
        XCTAssertFalse(TowingExperience.pickerCases.contains(.notSet))
        XCTAssertEqual(TowingExperience.pickerCases.count, TowingExperience.allCases.count - 1)
    }
}
