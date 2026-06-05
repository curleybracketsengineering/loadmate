import Foundation
import Combine
import SwiftData

@MainActor
final class DisclaimerViewModel: ObservableObject {
    func acceptDisclaimer(appState: AppState, in context: ModelContext) {
        appState.disclaimerAccepted = true
        appState.acceptedAt = Date()
        save(context)
    }

    private func save(_ context: ModelContext) {
        context.saveChanges()
    }
}
