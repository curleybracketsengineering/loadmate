import UIKit

/// Registers for remote notifications so CloudKit can deliver silent push for cross-device sync.
final class LoadMateAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        Task { @MainActor in
            CloudSyncMonitor.shared.refreshPushRegistrationStatus()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            CloudSyncMonitor.shared.handlePushRegistrationSuccess(deviceTokenByteCount: deviceToken.count)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            CloudSyncMonitor.shared.handlePushRegistrationFailure(error)
        }
    }
}
