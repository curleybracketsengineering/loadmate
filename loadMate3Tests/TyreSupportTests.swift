import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class TyreSupportTests: XCTestCase {
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

    func testDateCodeParsingNormalizesSlashFormat() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        let parsed = TyreSupport.parseDateCode("12/21", now: now)

        XCTAssertEqual(parsed?.normalized, "1221")
        XCTAssertEqual(parsed?.week, 12)
        XCTAssertEqual(parsed?.year, 2021)
        XCTAssertNotNil(parsed?.manufactureDate)
    }

    func testDateCodeRejectsImpossibleWeek() {
        XCTAssertNil(TyreSupport.parseDateCode("5421"))
        XCTAssertNil(TyreSupport.parseDateCode("0021"))
    }

    func testDateCodeRejectsFutureWeek() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        XCTAssertNil(TyreSupport.parseDateCode("4028", now: now))
    }

    func testAgeAssessmentTransitions() {
        let profile = TestFixtures.caravanProfile()
        let record = TyreRecord(vehicleID: profile.id, position: .caravanLeft)

        record.manufactureDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        XCTAssertEqual(TyreSupport.ageAssessment(for: record).status, "Current")

        record.manufactureDate = Calendar.current.date(byAdding: .year, value: -4, to: Date())
        XCTAssertEqual(TyreSupport.ageAssessment(for: record).status, "Approaching five years")

        record.manufactureDate = Calendar.current.date(byAdding: .year, value: -5, to: Date())
        XCTAssertEqual(TyreSupport.ageAssessment(for: record).status, "Replacement review recommended")

        record.manufactureDate = Calendar.current.date(byAdding: .year, value: -7, to: Date())
        XCTAssertEqual(TyreSupport.ageAssessment(for: record).status, "Replacement strongly recommended")
    }

    func testPressureConversionAndAssessment() {
        XCTAssertEqual(TyreSupport.convertPressure(4, from: .bar, to: .psi), 58.0152, accuracy: 0.0001)
        XCTAssertEqual(TyreSupport.convertPressure(58.0152, from: .psi, to: .bar), 4, accuracy: 0.0001)

        let record = TyreRecord(vehicleID: UUID(), position: .motorhomeFrontLeft)
        record.recommendedPressurePSI = 100
        record.latestPressurePSI = 88

        let assessment = TyreSupport.pressureAssessment(for: record)
        XCTAssertEqual(assessment.status, "Pressure significantly below target")
    }

    func testLayoutPositionGeneration() {
        XCTAssertEqual(
            TyreSupport.positions(for: .caravanSingleAxle, includeSpare: true),
            [.caravanLeft, .caravanRight, .caravanSpare]
        )
        XCTAssertEqual(
            TyreSupport.positions(for: .motorhomeSixWheel, includeSpare: false),
            [
                .motorhomeFrontLeft, .motorhomeFrontRight,
                .motorhomeRearLeftOuter, .motorhomeRearLeftInner,
                .motorhomeRearRightInner, .motorhomeRearRightOuter
            ]
        )
    }

    func testLayoutSummaryAndActionCount() {
        let profile = TestFixtures.caravanProfile()
        let near = TyreRecord(vehicleID: profile.id, position: .caravanLeft)
        let off = TyreRecord(vehicleID: profile.id, position: .caravanRight)
        let spare = TyreRecord(vehicleID: profile.id, position: .caravanSpare)
        near.manufacturer = "Michelin"
        near.manufactureDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        near.recommendedPressurePSI = 65
        near.latestPressurePSI = 65
        near.condition = .good
        off.manufacturer = "Michelin"
        off.manufactureDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        off.recommendedPressurePSI = 65
        off.latestPressurePSI = 65
        off.condition = .good

        let records = [near, off, spare]
        XCTAssertEqual(
            TyreSupport.layoutSummary(for: profile, records: records),
            "Caravan • 2 road tyres + spare"
        )
        XCTAssertEqual(TyreSupport.actionNeededCount(in: records), 1)
        XCTAssertEqual(TyreSupport.conditionCallToAction(for: spare), "Record DOT code")
        XCTAssertEqual(TyreSupport.dateCodeCaption(for: spare), "Date not recorded")
    }

    func testDateCodeCaptionAndCompactAge() {
        let record = TyreRecord(vehicleID: UUID(), position: .caravanLeft)
        record.manufactureWeek = 12
        record.manufactureYear = 2021
        record.manufactureDate = TyreSupport.isoWeekStart(year: 2021, week: 12)

        XCTAssertEqual(TyreSupport.dateCodeCaption(for: record), "Week 12 • 2021")
        XCTAssertNotNil(TyreSupport.compactAgeText(for: record.manufactureDate))
        XCTAssertFalse(TyreSupport.compactAgeText(for: record.manufactureDate)?.contains("old") == true)
    }

    func testInspectionRollupUpdatesTyreRecord() {
        let record = TyreRecord(vehicleID: UUID(), position: .caravanLeft)
        context.insert(record)

        TyreStore.addInspection(
            to: record,
            inspectionDate: Date(timeIntervalSince1970: 1000),
            pressurePSI: 65,
            treadDepthMM: 6.2,
            hasCuts: false,
            hasBulges: false,
            hasCracking: true,
            hasUnevenWear: false,
            hasEmbeddedObjects: false,
            valveAppearsSound: true,
            wheelNutsChecked: true,
            overallCondition: .monitor,
            notes: "Cracking visible",
            in: context
        )

        XCTAssertEqual(record.latestPressurePSI ?? 0, 65, accuracy: 0.001)
        XCTAssertEqual(record.latestTreadDepthMM ?? 0, 6.2, accuracy: 0.001)
        XCTAssertEqual(record.condition, .monitor)

        let inspections = try? context.fetch(FetchDescriptor<TyreInspection>())
        XCTAssertEqual(inspections?.count, 1)
    }
}
