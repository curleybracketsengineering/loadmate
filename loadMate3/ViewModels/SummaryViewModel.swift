import Foundation
import Combine

@MainActor
final class SummaryViewModel: ObservableObject {
    @Published private(set) var caravanSummary: WeightSummary?
    @Published private(set) var motorhomeSummary: MotorhomeWeightSummary?

    func refresh(profile: VehicleProfile?, trip: Trip?, loadedItems: [LoadedItem]) {
        guard let profile else {
            caravanSummary = nil
            motorhomeSummary = nil
            return
        }
        switch profile.kind {
        case .caravan:
            motorhomeSummary = nil
            caravanSummary = WeightCalculator.summary(profile: profile, loadedItems: loadedItems)
        case .motorhome:
            caravanSummary = nil
            motorhomeSummary = MotorhomeWeightCalculator.summary(profile: profile, loadedItems: loadedItems, trip: trip)
        }
    }
}
