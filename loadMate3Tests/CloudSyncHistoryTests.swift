import CloudKit
import XCTest
@testable import loadMate3

final class CloudSyncHistoryTests: XCTestCase {
    func testContextLabelsMatchRecommendedEventNames() {
        XCTAssertEqual(
            CloudSyncHistoryEntry.contextLabel(kind: .importFromCloud, phase: .started),
            "IMPORT started"
        )
        XCTAssertEqual(
            CloudSyncHistoryEntry.contextLabel(kind: .importFromCloud, phase: .partialFailure, models: ["VehicleProfile"]),
            "IMPORT partial failure — VehicleProfile"
        )
        XCTAssertEqual(
            CloudSyncHistoryEntry.contextLabel(kind: .exportToCloud, phase: .started),
            "EXPORT started"
        )
        XCTAssertEqual(
            CloudSyncHistoryEntry.contextLabel(kind: .exportToCloud, phase: .failed, models: ["Trip"]),
            "EXPORT failed — Trip"
        )
    }

    func testHistoryKeepsOnlyTheMostRecentTwentyEvents() {
        var events: [CloudSyncHistoryEntry] = []
        for index in 1...25 {
            let entry = CloudSyncHistoryEntry(
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                kind: .exportToCloud,
                phase: .started,
                context: "EXPORT started #\(index)"
            )
            events = CloudSyncEventHistory.prepending(entry, onto: events)
        }

        XCTAssertEqual(events.count, CloudSyncEventHistory.maxEntries)
        XCTAssertEqual(events.first?.context, "EXPORT started #25")
        XCTAssertEqual(events.last?.context, "EXPORT started #6")
    }

    func testPartialFailureHistoryUsesModelNamesAndOmitsRecordIDs() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.serverRejectedRequest.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Did not find record type 'CD_WarrantyPlan'"]
        )
        let recordID = CKRecord.ID(recordName: "user-visible-record-name")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Partial failure",
                "CKPartialErrorsByItemIDKey": [recordID: nested]
            ]
        )

        let models = CloudSyncErrorFormatting.involvedModels(in: partial)
        let entry = CloudSyncHistoryEntry.make(
            kind: .importFromCloud,
            started: false,
            succeeded: false,
            error: partial
        )

        XCTAssertTrue(CloudSyncErrorFormatting.isPartialFailure(partial))
        XCTAssertEqual(models, ["WarrantyPlan"])
        XCTAssertEqual(entry.phase, .partialFailure)
        XCTAssertEqual(entry.context, "IMPORT partial failure — WarrantyPlan")
        XCTAssertFalse(entry.context.contains("user-visible-record-name"))
    }

    func testChangeSummaryDescribesModelOperationsWithoutUserData() {
        let summary = SyncDebugChangeSummary.describe(
            inserted: ["VehicleProfile"],
            updated: ["Trip", "Trip"],
            deleted: ["LoadedItem"]
        )

        XCTAssertEqual(summary, "VehicleProfile: 1 inserted; Trip: 2 updated; LoadedItem: 1 deleted")
        XCTAssertEqual(
            SyncDebugChangeSummary.fallbackSummary(source: "VehicleProfileStore.save"),
            "VehicleProfile saved"
        )
        XCTAssertEqual(
            SyncDebugChangeSummary.fallbackSummary(source: "TripStore.save"),
            "Trip saved"
        )
    }
}
