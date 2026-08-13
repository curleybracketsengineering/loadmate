import Foundation
import SwiftUI

protocol VehicleLookupProviding: Sendable {
    func lookup(registration: String, forceRefresh: Bool) async throws -> VehicleLookupResult
}

/// Facade used by the rest of the app. Owns registration normalisation and a short-lived in-memory cache.
/// Swap the inner provider (Zyfy today, Lyneqo backend later) without changing views.
final class VehicleLookupService: VehicleLookupProviding, @unchecked Sendable {
    static let defaultCacheTTL: TimeInterval = 24 * 60 * 60
    static let infoPlistAPIKeyName = "ZYFY_API_KEY"

    private let provider: any VehicleLookupProviding
    private let cacheTTL: TimeInterval
    private let now: () -> Date
    private let lock = NSLock()
    private var cache: [String: CacheEntry] = [:]

    private struct CacheEntry {
        let result: VehicleLookupResult
        let storedAt: Date
    }

    init(
        provider: any VehicleLookupProviding,
        cacheTTL: TimeInterval = defaultCacheTTL,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.cacheTTL = cacheTTL
        self.now = now
    }

    func lookup(registration: String, forceRefresh: Bool) async throws -> VehicleLookupResult {
        let normalized = UKRegistration.normalizeForLookup(registration)
        guard UKRegistration.isPlausible(normalized) else {
            throw VehicleLookupError.invalidRegistration
        }

        if !forceRefresh, let cached = cachedResult(for: normalized) {
            return cached
        }

        let result = try await provider.lookup(registration: normalized, forceRefresh: forceRefresh)
        store(result, for: normalized)
        return result
    }

    /// Phase 1 live stack. The Zyfy key is read from Info.plist (xcconfig). This embedding is temporary and will move server-side.
    static func makeLive(session: URLSession = .shared) -> VehicleLookupService {
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: infoPlistAPIKeyName) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VehicleLookupService(
            provider: ZyfyVehicleLookupService(session: session, apiKey: apiKey)
        )
    }

    private func cachedResult(for registration: String) -> VehicleLookupResult? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = cache[registration] else { return nil }
        guard now().timeIntervalSince(entry.storedAt) < cacheTTL else {
            cache.removeValue(forKey: registration)
            return nil
        }
        return entry.result
    }

    private func store(_ result: VehicleLookupResult, for registration: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[registration] = CacheEntry(result: result, storedAt: now())
    }
}

struct UnconfiguredVehicleLookupProvider: VehicleLookupProviding {
    func lookup(registration: String, forceRefresh: Bool) async throws -> VehicleLookupResult {
        throw VehicleLookupError.configuration
    }
}

private struct VehicleLookupEnvironmentKey: EnvironmentKey {
    static let defaultValue: any VehicleLookupProviding = UnconfiguredVehicleLookupProvider()
}

extension EnvironmentValues {
    var vehicleLookup: any VehicleLookupProviding {
        get { self[VehicleLookupEnvironmentKey.self] }
        set { self[VehicleLookupEnvironmentKey.self] = newValue }
    }
}
