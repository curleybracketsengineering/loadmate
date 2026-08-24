import CloudKit
import XCTest
@testable import loadMate3

final class CloudSyncErrorFormattingTests: XCTestCase {
    func testFlattensPartialFailureNestedQueryableError() {
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
                "CKPartialErrorsByItemIDKey": [recordID: nested]
            ]
        )

        let description = CloudSyncErrorFormatting.description(for: partial)

        XCTAssertTrue(CloudSyncErrorFormatting.isMissingQueryableIndex(partial))
        XCTAssertTrue(description.contains("partialFailure"))
        XCTAssertTrue(description.contains("not marked queryable"))
    }

    func testPartialFailureIncludesItemIDNestedCodeUserInfoAndModel() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.invalidArguments.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Field 'recordName' is not marked queryable",
                NSDebugDescriptionErrorKey: "CKError 12"
            ]
        )
        let recordID = CKRecord.ID(recordName: "CD_AppState:1")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)",
                "CKPartialErrorsByItemIDKey": [recordID: nested]
            ]
        )

        let dump = CloudSyncErrorFormatting.dump(for: partial)

        XCTAssertTrue(dump.contains("PARTIAL FAILURE - 1 item"))
        XCTAssertTrue(dump.contains("Failed item:"))
        XCTAssertTrue(dump.contains("CD_AppState:1"))
        XCTAssertTrue(dump.contains("Nested CKError: 12 (invalidArguments)"))
        XCTAssertTrue(dump.contains("not marked queryable"))
        XCTAssertTrue(dump.contains("Nested userInfo:"))
        XCTAssertTrue(dump.contains("NSDebugDescription"))
        XCTAssertTrue(dump.contains("Record type / model: CD_AppState (SwiftData: AppState)"))
        XCTAssertTrue(dump.contains("☁️ CloudKit error: 2 (partialFailure)"))
    }

    func testPartialFailureListsEveryItemEvenWhenNestedErrorsMatch() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.serverRejectedRequest.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Did not find record type 'CD_WarrantyPlan'"]
        )
        let first = CKRecord.ID(recordName: "warranty-1")
        let second = CKRecord.ID(recordName: "warranty-2")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Partial failure",
                "CKPartialErrorsByItemIDKey": [first: nested, second: nested]
            ]
        )

        let dump = CloudSyncErrorFormatting.dump(for: partial)

        XCTAssertTrue(dump.contains("PARTIAL FAILURE - 2 items"))
        XCTAssertTrue(dump.contains("warranty-1"))
        XCTAssertTrue(dump.contains("warranty-2"))
        XCTAssertTrue(dump.contains("Nested CKError: 15 (serverRejectedRequest)"))
        XCTAssertTrue(dump.contains("CD_WarrantyPlan (SwiftData: WarrantyPlan)"))
    }

    func testPartialFailureIncludesUnderlyingErrorAndCKRecordType() {
        let record = CKRecord(
            recordType: "CD_AccidentPhoto",
            recordID: CKRecord.ID(recordName: "photo-1")
        )
        let underlying = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.unknownItem.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Record not found",
                "ServerErrorDescription": "Unknown item"
            ]
        )
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.batchRequestFailed.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Batch failed",
                NSUnderlyingErrorKey: underlying,
                "CKServerRecordKey": record
            ]
        )
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Partial failure",
                "CKPartialErrorsByItemIDKey": [record.recordID: nested]
            ]
        )

        let dump = CloudSyncErrorFormatting.dump(for: partial)

        XCTAssertTrue(dump.contains("Failed item:"))
        XCTAssertTrue(dump.contains("photo-1"))
        XCTAssertTrue(dump.contains("Nested CKError: 22 (batchRequestFailed)"))
        XCTAssertTrue(dump.contains("Underlying error:"))
        XCTAssertTrue(dump.contains("Nested CKError: 11 (unknownItem)"))
        XCTAssertTrue(dump.contains("ServerErrorDescription=Unknown item"))
        XCTAssertTrue(dump.contains("CD_AccidentPhoto (SwiftData: AccidentPhoto)"))
        XCTAssertTrue(dump.contains("CKRecord(type=CD_AccidentPhoto, id=photo-1)"))
    }

    func testCocoaWrappedPartialFailureStillExpandsItems() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.quotaExceeded.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Quota exceeded for CD_TyrePhoto"]
        )
        let recordID = CKRecord.ID(recordName: "tyre-photo-9")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)",
                "CKPartialErrorsByItemIDKey": [recordID: nested]
            ]
        )
        let cocoa = NSError(
            domain: NSCocoaErrorDomain,
            code: 134406,
            userInfo: [
                NSLocalizedDescriptionKey: "CloudKit mirroring failed",
                NSUnderlyingErrorKey: partial
            ]
        )

        let dump = CloudSyncErrorFormatting.dump(for: cocoa)
        let description = CloudSyncErrorFormatting.description(for: cocoa)

        XCTAssertTrue(dump.contains("CocoaError 134406"))
        XCTAssertTrue(dump.contains("Underlying error:"))
        XCTAssertTrue(dump.contains("PARTIAL FAILURE - 1 item"))
        XCTAssertTrue(dump.contains("tyre-photo-9"))
        XCTAssertTrue(dump.contains("CD_TyrePhoto (SwiftData: TyrePhoto)"))
        XCTAssertTrue(description.contains("tyre-photo-9"))
        XCTAssertTrue(description.contains("quotaExceeded"))
    }
}
