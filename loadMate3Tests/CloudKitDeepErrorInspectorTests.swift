import CloudKit
import XCTest
@testable import loadMate3

final class CloudKitDeepErrorInspectorTests: XCTestCase {
    func testInspectIncludesStartAndEndMarkers() {
        let error = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)"]
        )

        let dump = CloudKitDeepErrorInspector.inspect(error: error)

        XCTAssertTrue(dump.contains(CloudKitDeepErrorInspector.startMarker))
        XCTAssertTrue(dump.contains(CloudKitDeepErrorInspector.endMarker))
        XCTAssertTrue(dump.contains("Swift error type:"))
        XCTAssertTrue(dump.contains("NSError domain: CKErrorDomain"))
        XCTAssertTrue(dump.contains("NSError code: 2"))
        XCTAssertTrue(dump.contains("CKError readable code: partialFailure"))
        XCTAssertTrue(dump.contains("partialErrorsByItemID: NONE"))
        XCTAssertTrue(dump.contains("NSUnderlyingErrorKey: NONE"))
        XCTAssertTrue(dump.contains("NSDetailedErrorsKey: NONE"))
        XCTAssertTrue(dump.contains("CKPartialErrorsByItemIDKey: absent"))
    }

    func testInspectEnumeratesEveryPartialFailureItem() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.serverRejectedRequest.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Did not find record type 'CD_WarrantyPlan'",
                NSDebugDescriptionErrorKey: "CKError 15",
            ]
        )
        let first = CKRecord.ID(recordName: "warranty-1")
        let second = CKRecord.ID(recordName: "warranty-2")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Partial failure",
                "CKPartialErrorsByItemIDKey": [first: nested, second: nested],
            ]
        )

        let dump = CloudKitDeepErrorInspector.inspect(error: partial)

        XCTAssertTrue(dump.contains("partialErrorsByItemID: 2 items"))
        XCTAssertTrue(dump.contains("Partial failure item:"))
        XCTAssertTrue(dump.contains("warranty-1"))
        XCTAssertTrue(dump.contains("warranty-2"))
        XCTAssertTrue(dump.contains("Nested CKError code/name: 15 (serverRejectedRequest)"))
        XCTAssertTrue(dump.contains("CKPartialErrorsByItemIDKey: present"))
        XCTAssertTrue(dump.contains("NSDebugDescription"))
    }

    func testInspectWalksCocoaWrappedPartialFailureAndUserInfoKeys() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.invalidArguments.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Field 'recordName' is not marked queryable"]
        )
        let recordID = CKRecord.ID(recordName: "CD_AppState:1")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)",
                "CKPartialErrorsByItemIDKey": [recordID: nested],
            ]
        )
        let cocoa = NSError(
            domain: NSCocoaErrorDomain,
            code: 134406,
            userInfo: [
                NSLocalizedDescriptionKey: "CloudKit mirroring failed",
                NSUnderlyingErrorKey: partial,
            ]
        )

        let dump = CloudKitDeepErrorInspector.inspect(error: cocoa)

        XCTAssertTrue(dump.contains("NSError domain: NSCocoaErrorDomain"))
        XCTAssertTrue(dump.contains("NSError code: 134406"))
        XCTAssertTrue(dump.contains("NSUnderlyingErrorKey: present"))
        XCTAssertTrue(dump.contains("CKError readable code: partialFailure"))
        XCTAssertTrue(dump.contains("CD_AppState:1"))
        XCTAssertTrue(dump.contains("Nested CKError code/name: 12 (invalidArguments)"))
        XCTAssertTrue(dump.contains("not marked queryable"))
    }

    @MainActor
    func testReportKeepsLastDetailedFailureSeparateFromHistory() {
        let snapshot = SyncDebugSnapshot(
            accountStatus: .available,
            lastCheckedAt: nil,
            lastErrorDescription: "CKErrorDomain error 2",
            lastSyncEventSummary: "Export FAILED",
            recentSyncEventLines: ["EXPORT failed"],
            lastSuccessfulImportAt: nil,
            lastSuccessfulExportAt: nil,
            lastDetailedCloudKitFailure: """
            === DEEP CLOUDKIT ERROR INSPECTION START ===
            CKError readable code: partialFailure
            partialErrorsByItemID: NONE
            === DEEP CLOUDKIT ERROR INSPECTION END ===
            """,
            lastMinimalSyncTestResult: "Not run",
            isRegisteredForRemoteNotifications: true,
            pushRegistrationDetail: "Registered",
            cloudKitSchemaDetail: "CloudKit connectivity/schema probe:\nCD_AppState reachable",
            deviceName: "Test iPad",
            bundleID: "test.bundle",
            appVersion: "4.0",
            buildNumber: "49",
            vehicleProfileCount: 2,
            tripCount: 2,
            loadedItemCount: 0,
            libraryItemCount: 0,
            checklistSectionCount: 5,
            checklistItemCount: 68,
            appStateCount: 1,
            activeProfileName: "My Caravan",
            syncProbeSequence: 0,
            syncProbeValue: "",
            syncProbeUpdatedAt: nil,
            syncProbeUpdatedBy: ""
        )

        let report = SyncDebugLogger.shared.makeReport(snapshot: snapshot)

        XCTAssertTrue(report.contains("Last Detailed CloudKit Failure"))
        XCTAssertTrue(report.contains(CloudKitDeepErrorInspector.startMarker))
        XCTAssertTrue(report.contains("partialErrorsByItemID: NONE"))
        XCTAssertTrue(report.contains("CloudKit connectivity/schema probe:"))
        XCTAssertFalse(report.contains("Schema OK — CD_AppState reachable in this environment"))
        XCTAssertTrue(report.contains("SwiftData CloudKit model audit"))
    }

    func testModelAuditListsCloudKitModelsAndDoesNotMutateSchema() {
        let report = CloudKitModelAudit.report()

        XCTAssertTrue(report.contains("Model name: AppState"))
        XCTAssertTrue(report.contains("Model name: VehicleProfile"))
        XCTAssertTrue(report.contains("Model name: Trip"))
        XCTAssertTrue(report.contains("Model name: ChecklistSection"))
        XCTAssertTrue(report.contains("Model name: ChecklistItem"))
        XCTAssertTrue(report.contains("Attributes:"))
        XCTAssertTrue(report.contains("Relationships:"))
        XCTAssertTrue(report.contains("CloudKit-sensitive flags"))
    }

    func testSeedIsolationDefaultsToOff() {
        SyncDebugSeedIsolation.overrideForTests = false
        XCTAssertFalse(SyncDebugSeedIsolation.isAutomaticSeedingSuppressed)
        SyncDebugSeedIsolation.overrideForTests = true
        XCTAssertTrue(SyncDebugSeedIsolation.isAutomaticSeedingSuppressed)
        SyncDebugSeedIsolation.overrideForTests = nil
    }
}
