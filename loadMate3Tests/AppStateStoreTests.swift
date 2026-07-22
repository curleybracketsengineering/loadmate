import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class AppStateStoreTests: XCTestCase {
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

    func testResolveCreatesSingletonAppState() {
        let state = AppStateStore.resolve(in: context)

        XCTAssertEqual(state.id, LoadMateSyncIDs.appState)
        XCTAssertFalse(state.disclaimerAccepted)

        let fetched = try? context.fetch(FetchDescriptor<AppState>())
        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.id, LoadMateSyncIDs.appState)
    }

    func testResolveMergesDuplicateAppStates() {
        let legacyA = AppState(id: UUID(), disclaimerAccepted: true, acceptedAt: Date(timeIntervalSince1970: 100))
        let legacyB = AppState(id: UUID(), activeProfileID: UUID())
        context.insert(legacyA)
        context.insert(legacyB)

        let merged = AppStateStore.resolve(in: context)

        XCTAssertEqual(merged.id, LoadMateSyncIDs.appState)
        XCTAssertTrue(merged.disclaimerAccepted)
        XCTAssertNotNil(merged.acceptedAt)
        XCTAssertNotNil(merged.activeProfileID)

        let fetched = try? context.fetch(FetchDescriptor<AppState>())
        XCTAssertEqual(fetched?.count, 1)
    }

    func testSharedContainerCanBeCreated() throws {
        // Validates CloudKit schema requirements (optional relationships, no unique constraints).
        _ = try LoadMateModelContainer.makeShared()
    }

    func testCanonicalPrefersSingletonRecord() {
        let canonical = AppState()
        let other = AppState(id: UUID())
        context.insert(canonical)
        context.insert(other)

        let resolved = AppStateStore.canonical(from: [other, canonical])

        XCTAssertEqual(resolved?.id, LoadMateSyncIDs.appState)
    }
}
