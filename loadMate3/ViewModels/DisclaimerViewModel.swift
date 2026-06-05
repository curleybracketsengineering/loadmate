import Foundation
import Combine
import SwiftData

@MainActor
final class DisclaimerViewModel: ObservableObject {
    func ensureAppState(in context: ModelContext, existing: AppState?) -> AppState {
        if let existing { return existing }
        let state = AppState()
        context.insert(state)
        save(context)
        return state
    }

    func acceptDisclaimer(appState: AppState, in context: ModelContext) {
        appState.disclaimerAccepted = true
        appState.acceptedAt = Date()
        save(context)
    }

    private func save(_ context: ModelContext) {
        context.saveChanges()
    }
}
