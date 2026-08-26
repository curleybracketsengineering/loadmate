import Foundation

enum CloudKitEnvironment {
    static let productionContainerID = "iCloud.com.curleybracketsengineering.loadMate3"
    static let diagnosticContainerID = "iCloud.com.curleybracketsengineering.loadMate3.debug"

    /// Isolation tests must not write to the live production container.
    static var isolationWritesEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: isolationWritesDefaultsKey)
        #else
        false
        #endif
    }

    static let isolationWritesDefaultsKey = "cloudKitIsolationWritesEnabled"

    /// The debug CloudKit container is not in entitlements until created in the developer portal.
    static var isDiagnosticContainerConfigured: Bool { false }

    static var isolationStatusLine: String {
        if isolationWritesEnabled, isDiagnosticContainerConfigured {
            return "ENABLED against diagnostic container only"
        }
        return "DISABLED against production"
    }

    static var diagnosticContainerStatusLine: String {
        isDiagnosticContainerConfigured ? "configured" : "not configured"
    }

    static let productionDisabledMessage = """
    CloudKit isolation testing temporarily disabled.

    The previous diagnostic store shared the production CloudKit container and could leak test records into the live app.
    """

    static let historicalIsolationFindings = """
    Historical isolation results (do not rerun against production):

    AppState-only: PASSED
    Core Vehicle (AppState + VehicleProfile + Trip): PASSED
    Checklist Model (AppState + VehicleProfile + Trip + ChecklistSection + ChecklistItem): PASSED
    """

    static let diagnosticContainerSetupSteps = """
    Manual Apple Developer step before re-enabling isolation tests:

    1. In Certificates, Identifiers & Profiles, create CloudKit container
       \(diagnosticContainerID)
    2. Add that identifier to the app’s iCloud entitlements (DEBUG only).
    3. Do not change the production container
       \(productionContainerID)
    4. Isolation tests will then use the diagnostic container only.

    Until that exists, isolation writes stay disabled.
    """
}
