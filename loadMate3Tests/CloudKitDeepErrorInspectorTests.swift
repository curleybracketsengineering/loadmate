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
            cloudKitIsolationTestReport: "CloudKit Model Isolation Test\nStatus: Not run",
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
        XCTAssertTrue(report.contains("CloudKit Model Isolation Test"))
    }

    func testModelAuditDoesNotFlagBlankOriginalNameAsRename() {
        XCTAssertFalse(CloudKitModelAudit.isGenuineRename(originalName: "", currentName: "name"))
        XCTAssertFalse(CloudKitModelAudit.isGenuineRename(originalName: "   ", currentName: "name"))
        XCTAssertFalse(CloudKitModelAudit.isGenuineRename(originalName: "name", currentName: "name"))
        XCTAssertTrue(CloudKitModelAudit.isGenuineRename(originalName: "old_name", currentName: "name"))

        let report = CloudKitModelAudit.report()
        XCTAssertFalse(report.contains("renamed from  "))
        XCTAssertFalse(report.contains("renamed from ]"))
        XCTAssertFalse(report.contains("originalName=]"))
    }

    func testIsolationStoreIsSeparateFromProductionAndAppStateOnly() {
        let isolationURL = LoadMateModelContainer.appStateOnlyIsolationStoreURL
        XCTAssertTrue(isolationURL.path.contains("LoadMateCloudKitIsolation"))
        XCTAssertTrue(isolationURL.path.contains("AppStateOnly"))
        XCTAssertEqual(LoadMateModelContainer.appStateOnlyIsolationSchema.entities.count, 1)
        XCTAssertEqual(LoadMateModelContainer.appStateOnlyIsolationSchema.entities.first?.name, "AppState")
        XCTAssertGreaterThan(LoadMateModelContainer.schema.entities.count, 1)

        let coreURL = LoadMateModelContainer.coreVehicleIsolationStoreURL
        XCTAssertTrue(coreURL.path.contains("LoadMateCloudKitIsolation"))
        XCTAssertTrue(coreURL.path.contains("CoreVehicle"))
        XCTAssertFalse(coreURL.path.contains("default.store"))
        let coreNames = Set(LoadMateModelContainer.coreVehicleIsolationSchema.entities.map(\.name))
        XCTAssertTrue(coreNames.contains("AppState"))
        XCTAssertTrue(coreNames.contains("VehicleProfile"))
        XCTAssertTrue(coreNames.contains("Trip"))
        XCTAssertFalse(coreNames.contains("ChecklistItem"))
        XCTAssertLessThan(coreNames.count, LoadMateModelContainer.schema.entities.count)
        XCTAssertNotEqual(isolationURL, coreURL)
    }

    func testIsolationReportDescribesAppStateOnlyOutcome() {
        var report = CloudKitIsolationTestReport()
        report.status = .passed
        report.localStoreCreated = true
        report.localSave = "succeeded"
        report.insertedAppStateCount = 1
        report.setup = "succeeded"
        report.export = "succeeded"
        report.probeValue = "appstate-isolation-test"
        report.conclusion = "APPSTATE-ONLY TEST PASSED"

        let text = report.formatted
        XCTAssertTrue(text.contains("CloudKit Model Isolation Test"))
        XCTAssertTrue(text.contains("Test: AppState only"))
        XCTAssertTrue(text.contains("Status: PASSED"))
        XCTAssertTrue(text.contains("AppState = 1"))
        XCTAssertTrue(text.contains("Local save:"))
        XCTAssertTrue(text.contains("succeeded"))
        XCTAssertTrue(text.contains("SETUP succeeded"))
        XCTAssertTrue(text.contains("EXPORT succeeded"))
        XCTAssertTrue(text.contains("APPSTATE-ONLY TEST PASSED"))
    }

    func testIsolationReportDescribesCoreVehicleOutcome() {
        var report = CloudKitIsolationTestReport()
        report.scenario = .coreVehicle
        report.testName = CloudKitIsolationScenario.coreVehicle.testName
        report.modelContainerLines = CloudKitIsolationScenario.coreVehicle.modelContainerLines
        report.relationshipLines = CloudKitIsolationScenario.coreVehicle.relationshipLines
        report.status = .failed
        report.localStoreCreated = true
        report.localSave = "succeeded"
        report.insertedAppStateCount = 1
        report.insertedVehicleProfileCount = 1
        report.insertedTripCount = 1
        report.setup = "succeeded"
        report.export = "failed"
        report.probeValue = "core-vehicle-isolation-test"
        report.conclusion = "CORE VEHICLE TEST FAILED"

        let text = report.formatted
        XCTAssertTrue(text.contains("Test: AppState + VehicleProfile + Trip"))
        XCTAssertTrue(text.contains("Status: FAILED"))
        XCTAssertTrue(text.contains("VehicleProfile = 1"))
        XCTAssertTrue(text.contains("Trip = 1"))
        XCTAssertTrue(text.contains("Trip.profile -> VehicleProfile"))
        XCTAssertTrue(text.contains("VehicleProfile.trips -> Trip"))
        XCTAssertTrue(text.contains("CORE VEHICLE TEST FAILED"))
        XCTAssertTrue(text.contains("EXPORT failed"))
    }

    func testMinimalSyncStatusDoesNotTreatLocalProbeAsSuccess() {
        XCTAssertEqual(MinimalSyncTestStatus.notRun.rawValue, "Not run")
        XCTAssertEqual(MinimalSyncTestStatus.waitingForCloudKit.rawValue, "Waiting for CloudKit")
        XCTAssertEqual(MinimalSyncTestStatus.exportSucceeded.rawValue, "CloudKit export succeeded")
        XCTAssertNotEqual(MinimalSyncTestStatus.localSaveSucceeded, MinimalSyncTestStatus.exportSucceeded)
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
