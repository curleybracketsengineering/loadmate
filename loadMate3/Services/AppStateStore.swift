import Foundation
import SwiftData

enum AppStateStore {
    /// Picks the canonical app-state record without mutating the store.
    static func canonical(from states: [AppState]) -> AppState? {
        guard !states.isEmpty else { return nil }
        return states.max(by: { rank($0) < rank($1) })
    }

    /// Ensures exactly one app-state record exists, merging and removing duplicates when needed.
    @MainActor
    static func ensure(in context: ModelContext, queried states: [AppState] = []) -> AppState {
        let resolved = states.isEmpty ? ((try? context.fetch(FetchDescriptor<AppState>())) ?? []) : states
        switch resolved.count {
        case 0:
            let state = AppState()
            context.insert(state)
            context.saveChanges()
            return state
        case 1:
            return resolved[0]
        default:
            return deduplicate(resolved, in: context)
        }
    }

    @MainActor
    private static func deduplicate(_ states: [AppState], in context: ModelContext) -> AppState {
        guard let keeper = canonical(from: states) else {
            return ensure(in: context)
        }

        for state in states where state.persistentModelID != keeper.persistentModelID {
            mergeFields(from: state, into: keeper)
            context.delete(state)
        }

        context.saveChanges("Saving app state")
        return keeper
    }

    private static func rank(_ state: AppState) -> Int {
        var score = 0
        if state.disclaimerAccepted { score += 100 }
        if state.activeProfileID != nil { score += 10 }
        if state.acceptedAt != nil { score += 1 }
        return score
    }

    private static func mergeFields(from duplicate: AppState, into canonical: AppState) {
        if duplicate.disclaimerAccepted {
            canonical.disclaimerAccepted = true
            switch (canonical.acceptedAt, duplicate.acceptedAt) {
            case (nil, let date?):
                canonical.acceptedAt = date
            case (let existing?, let date?) where date > existing:
                canonical.acceptedAt = date
            default:
                break
            }
        }

        if canonical.activeProfileID == nil {
            canonical.activeProfileID = duplicate.activeProfileID
        }
    }
}
