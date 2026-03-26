import Foundation
import Combine
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    func ensureConfig(in context: ModelContext, existing: SetupConfig?) -> SetupConfig {
        if let existing { return existing }
        let newConfig = SetupConfig()
        context.insert(newConfig)
        save(context)
        return newConfig
    }

    func resetFactors(config: SetupConfig, in context: ModelContext) {
        config.factorFrontLocker = 0.25
        config.factorFront = 0.15
        config.factorMiddle = 0.0
        config.factorRear = -0.20
        config.factorBikeRack = -0.35
        save(context)
    }

    func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
