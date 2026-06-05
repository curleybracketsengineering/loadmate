import Foundation
import SwiftData

extension ModelContext {
    /// Persists pending changes, surfacing any failure to the user via `AppErrorCenter`.
    ///
    /// This replaces the per-type `try? save()` + `assertionFailure` boilerplate that was
    /// duplicated across the stores and view models. `assertionFailure` is a no-op in release
    /// builds, so a failed save (e.g. saving weighbridge data) previously vanished silently.
    /// - Parameter operation: Short, user-facing description of what was being saved.
    @MainActor
    func saveChanges(_ operation: String = "Saving your changes") {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            AppErrorCenter.shared.report(error, while: operation)
        }
    }
}
