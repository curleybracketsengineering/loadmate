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
}
