import Foundation
import Combine
import SwiftData

@MainActor
final class SummaryViewModel: ObservableObject {
    @Published private(set) var summary: WeightSummary?

    func refresh(config: SetupConfig?, loadedItems: [LoadedItem]) {
        guard let config else {
            summary = nil
            return
        }
        summary = WeightCalculator.summary(config: config, loadedItems: loadedItems)
    }
}
