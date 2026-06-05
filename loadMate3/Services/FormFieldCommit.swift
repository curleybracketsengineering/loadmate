import UIKit

extension Notification.Name {
    /// Posted before an explicit form save so in-flight numeric fields flush draft text to their bindings.
    static let commitPendingNumericFieldEdits = Notification.Name("commitPendingNumericFieldEdits")
}

enum FormFieldCommit {
    @MainActor
    static func commitPendingEdits() {
        NotificationCenter.default.post(name: .commitPendingNumericFieldEdits, object: nil)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
