import XCTest
@testable import loadMate3

final class SafetySupportTests: XCTestCase {
    func testLoadCheckIsDueWhenMotorhomeSetupIncompleteEvenIfEmptyLoadLooksSafe() {
        let profile = TestFixtures.motorhomeProfile(gross: 0, frontAxle: 0, rearAxle: 0, mam: 3500)

        XCTAssertFalse(profile.isConfiguredForWeightCalculations)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [])
        XCTAssertTrue(summary.isOverallSafe)

        let items = SafetySupport.todayChecklist(
            profile: profile,
            caravanSummary: nil,
            motorhomeSummary: summary,
            checklistSections: [],
            tyreRecords: []
        )
        let load = items.first { $0.id == "load" }

        XCTAssertEqual(load?.status, .due)
    }

    func testLoadCheckIsCompleteWhenMotorhomeIsConfiguredAndWithinLimits() {
        let profile = TestFixtures.motorhomeProfile()
        XCTAssertTrue(profile.isConfiguredForWeightCalculations)

        let summary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: [])
        let items = SafetySupport.todayChecklist(
            profile: profile,
            caravanSummary: nil,
            motorhomeSummary: summary,
            checklistSections: [],
            tyreRecords: []
        )
        let load = items.first { $0.id == "load" }

        XCTAssertEqual(load?.status, summary.isOverallSafe ? .complete : .due)
    }

    func testLoadCheckIsDueWhenCaravanSetupIncomplete() {
        let profile = TestFixtures.caravanProfile(baseWeight: 1200, mtplm: 1500, towBall: 0)
        XCTAssertFalse(profile.isConfiguredForWeightCalculations)

        let items = SafetySupport.todayChecklist(
            profile: profile,
            caravanSummary: WeightCalculator.summary(profile: profile, loadedItems: []),
            motorhomeSummary: nil,
            checklistSections: [],
            tyreRecords: []
        )
        let load = items.first { $0.id == "load" }
        let nose = items.first { $0.id == "nose" }

        XCTAssertEqual(load?.status, .due)
        XCTAssertEqual(nose?.status, .due)
    }
}
