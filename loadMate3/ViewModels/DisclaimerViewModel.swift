import Foundation
import Combine
import SwiftData

@MainActor
final class DisclaimerViewModel: ObservableObject {
    func ensureAppState(in context: ModelContext, existing: AppState?) -> AppState {
        if let existing { return existing }
        return AppStateStore.resolve(in: context)
    }

    func acceptDisclaimer(appState: AppState, in context: ModelContext) {
        appState.disclaimerAccepted = true
        appState.acceptedAt = Date()
        save(context)
    }

    private func save(_ context: ModelContext) {
        _ = SyncDebugSaveHelper.save(context, source: "DisclaimerViewModel.save")
    }
}
