import Foundation
import Combine
import SwiftData

@MainActor
final class LocationViewModel: ObservableObject {
    func updateZone(for loadedItem: LoadedItem, to zone: LoadZone, in context: ModelContext) {
        loadedItem.zone = zone
        context.saveChanges("Updating the load location")
    }
}
