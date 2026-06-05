import SwiftData
import Testing
@testable import loadMate3

@MainActor
@Suite("App state store")
struct AppStateStoreTests {
    @Test("Ensure inserts a singleton when the store is empty")
    func ensureCreatesSingleton() throws {
        let context = try TestSupport.makeContext()
        let state = AppStateStore.ensure(in: context)

        let stored = try context.fetch(FetchDescriptor<AppState>())
        #expect(stored.count == 1)
        #expect(stored[0].persistentModelID == state.persistentModelID)
    }

    @Test("Canonical prefers accepted disclaimer and active profile")
    func canonicalRanking() {
        let accepted = AppState(disclaimerAccepted: true, acceptedAt: .now, activeProfileID: UUID())
        let bare = AppState()

        #expect(AppStateStore.canonical(from: [bare, accepted])?.disclaimerAccepted == true)
        #expect(AppStateStore.canonical(from: [bare, accepted])?.activeProfileID == accepted.activeProfileID)
    }

    @Test("Ensure merges duplicate records and keeps one canonical row")
    func deduplicatesDuplicates() throws {
        let context = try TestSupport.makeContext()
        let profileID = UUID()

        let keeper = AppState(disclaimerAccepted: true, acceptedAt: Date(timeIntervalSince1970: 100), activeProfileID: profileID)
        let duplicate = AppState(disclaimerAccepted: false, activeProfileID: nil)
        context.insert(keeper)
        context.insert(duplicate)

        let resolved = AppStateStore.ensure(in: context, queried: [keeper, duplicate])
        let stored = try context.fetch(FetchDescriptor<AppState>())

        #expect(stored.count == 1)
        #expect(resolved.persistentModelID == keeper.persistentModelID)
        #expect(resolved.disclaimerAccepted)
        #expect(resolved.activeProfileID == profileID)
    }
}
