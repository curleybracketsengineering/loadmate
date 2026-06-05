import Foundation
import SwiftData

enum AppStateStore {
    /// Returns the existing app state or inserts and persists a new singleton record.
    @MainActor
    static func ensure(in context: ModelContext, existing: AppState?) -> AppState {
        if let existing { return existing }
        let state = AppState()
        context.insert(state)
        context.saveChanges()
        return state
    }
}
