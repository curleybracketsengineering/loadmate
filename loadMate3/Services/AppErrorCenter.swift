import Foundation
import Combine

/// App-wide channel for surfacing recoverable failures (currently persistence errors)
/// to the user. A single shared instance is observed at the root and presented as an alert,
/// so static stores and view models can report problems without threading UI state through
/// every call site.
@MainActor
final class AppErrorCenter: ObservableObject {
    static let shared = AppErrorCenter()

    /// Non-nil when there is a message to show the user; setting it drives the root alert.
    @Published var message: String?

    private init() {}

    func report(_ error: Error, while operation: String) {
        message = "\(operation) failed.\n\(error.localizedDescription)"
    }

    func clear() {
        message = nil
    }
}
