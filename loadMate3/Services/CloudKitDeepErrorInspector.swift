import CloudKit
import CoreData
import Foundation

/// Recursive CloudKit / SwiftData error dump for the sync debug report.
/// Does not change sync behaviour; it only observes the error object the system already delivered.
enum CloudKitDeepErrorInspector {
    static let startMarker = "=== DEEP CLOUDKIT ERROR INSPECTION START ==="
    static let endMarker = "=== DEEP CLOUDKIT ERROR INSPECTION END ==="

    private static let maxDepth = 10
    private static let maxPartialItems = 100
    private static let maxUserInfoValueLength = 800

    private static let partialErrorsKey = "CKPartialErrorsByItemIDKey"
    private static let ancestorRecordKey = "CKRecordChangedErrorAncestorRecordKey"
    private static let clientRecordKey = "CKRecordChangedErrorClientRecordKey"
    private static let serverRecordKey = "CKRecordChangedErrorServerRecordKey"
    private static let retryAfterKey = "CKErrorRetryAfterKey"

    struct EventContext {
        var kind: String
        var succeeded: Bool
        var startDate: Date?
        var endDate: Date?
        var identifier: String?
        var storeIdentifier: String?
        var notificationKeys: [String]
        var extraNotificationErrors: [Error]
        var countsAtStart: String?
        var countsAtFailure: String?
        var duration: String?
        var uptimeSeconds: TimeInterval
        var pendingMinimalSyncTestID: String?
    }

    static func inspect(error: Error?, context: EventContext) -> String {
        var lines: [String] = [startMarker]
        var seen = Set<ObjectIdentifier>()

        lines.append("Kind: \(context.kind)")
        lines.append("Event succeeded: \(context.succeeded)")
        lines.append("Event identifier: \(context.identifier ?? "nil")")
        lines.append("Store identifier: \(context.storeIdentifier ?? "nil")")
        lines.append("Start: \(formatDate(context.startDate))")
        lines.append("End: \(formatDate(context.endDate))")
        lines.append("Duration: \(context.duration ?? "unknown")")
        lines.append(String(format: "Process uptime: %.3fs", context.uptimeSeconds))
        lines.append("Notification userInfo keys: \(context.notificationKeys.isEmpty ? "none" : context.notificationKeys.joined(separator: ", "))")
        if let pending = context.pendingMinimalSyncTestID {
            lines.append("Pending minimal sync test id: \(pending)")
        }
        if let counts = context.countsAtStart {
            lines.append("Counts at \(context.kind) started: \(counts)")
        } else {
            lines.append("Counts at \(context.kind) started: unavailable")
        }
        if let counts = context.countsAtFailure {
            lines.append("Counts at \(context.kind) failed: \(counts)")
        } else {
            lines.append("Counts at \(context.kind) failed: unavailable")
        }

        if let error {
            inspectSwiftError(error, into: &lines)
            inspectNSErrorTree(error, depth: 0, seen: &seen, into: &lines)
        } else {
            lines.append("event.error: NIL")
            lines.append("The CloudKit event reported failure without an Error payload.")
        }

        if !context.extraNotificationErrors.isEmpty {
            lines.append("Additional errors in notification userInfo: \(context.extraNotificationErrors.count)")
            for extra in context.extraNotificationErrors {
                inspectNSErrorTree(extra, depth: 0, seen: &seen, into: &lines)
            }
        }

        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    static func inspect(error: Error) -> String {
        inspect(
            error: error,
            context: EventContext(
                kind: "UNKNOWN",
                succeeded: false,
                startDate: nil,
                endDate: nil,
                identifier: nil,
                storeIdentifier: nil,
                notificationKeys: [],
                extraNotificationErrors: [],
                countsAtStart: nil,
                countsAtFailure: nil,
                duration: nil,
                uptimeSeconds: ProcessInfo.processInfo.systemUptime,
                pendingMinimalSyncTestID: nil
            )
        )
    }

    private static func inspectSwiftError(_ error: Error, into lines: inout [String]) {
        let nsError = error as NSError
        lines.append("Swift error type: \(String(describing: type(of: error)))")
        lines.append("Description: \(error.localizedDescription)")
        lines.append("Reflecting description: \(redactUnsafelyLarge(String(reflecting: error)))")
        lines.append("String(describing:): \(redactUnsafelyLarge(String(describing: error)))")
        lines.append("NSError domain: \(nsError.domain)")
        lines.append("NSError code: \(nsError.code)")
        lines.append("NSError localizedDescription: \(nsError.localizedDescription)")
        lines.append("NSError userInfo:")
        appendUserInfoPairs(nsError.userInfo, indent: "  ", into: &lines)

        let mirror = Mirror(reflecting: error)
        if mirror.children.contains(where: { _ in true }) {
            lines.append("Swift Mirror children:")
            for child in mirror.children.prefix(30) {
                let label = child.label ?? "_"
                lines.append("  \(label) = \(describeSafely(child.value))")
            }
        }
    }

    private static func inspectNSErrorTree(
        _ error: Error,
        depth: Int,
        seen: inout Set<ObjectIdentifier>,
        into lines: inout [String]
    ) {
        let nsError = error as NSError
        let identity = ObjectIdentifier(nsError)
        if !seen.insert(identity).inserted {
            lines.append(indent(depth) + "Depth: \(depth) (already visited \(nsError.domain) \(nsError.code))")
            return
        }
        if depth > maxDepth {
            lines.append(indent(depth) + "Depth: \(depth) truncated (max \(maxDepth))")
            return
        }

        lines.append(indent(depth) + "Depth: \(depth)")
        lines.append(indent(depth) + "Domain: \(nsError.domain)")
        lines.append(indent(depth) + "Code: \(nsError.code)")
        lines.append(indent(depth) + "Description: \(nsError.localizedDescription)")
        lines.append(indent(depth) + "Failure reason: \(nsError.localizedFailureReason ?? "NONE")")
        lines.append(indent(depth) + "Recovery suggestion: \(nsError.localizedRecoverySuggestion ?? "NONE")")
        let userInfoKeys = nsError.userInfo.keys.map { String(describing: $0) }.sorted()
        lines.append(indent(depth) + "UserInfo keys: \(userInfoKeys.isEmpty ? "NONE" : userInfoKeys.joined(separator: ", "))")

        if let ckError = asCKError(error) {
            inspectCKError(ckError, nsError: nsError, depth: depth, into: &lines)
        } else if nsError.domain == CKErrorDomain {
            inspectCKErrorFields(
                code: CKError.Code(rawValue: nsError.code),
                nsError: nsError,
                typedCKError: nil,
                depth: depth,
                into: &lines
            )
        }

        inspectCloudKitUserInfoKeys(nsError.userInfo, depth: depth, into: &lines)

        let partial = partialErrorMap(from: nsError)
        if let partial, !partial.isEmpty {
            let items = partial.sorted { describeItemID($0.key) < describeItemID($1.key) }
            lines.append(indent(depth) + "partialErrorsByItemID: \(items.count) item\(items.count == 1 ? "" : "s")")
            for (itemID, itemError) in items.prefix(maxPartialItems) {
                inspectPartialItem(itemID: itemID, itemError: itemError, depth: depth + 1, seen: &seen, into: &lines)
            }
            if items.count > maxPartialItems {
                lines.append(indent(depth + 1) + "… \(items.count - maxPartialItems) more partial items omitted")
            }
        } else {
            lines.append(indent(depth) + "partialErrorsByItemID: NONE")
        }

        if nsError.userInfo[NSUnderlyingErrorKey] == nil {
            lines.append(indent(depth) + "NSUnderlyingErrorKey: NONE")
        } else {
            lines.append(indent(depth) + "NSUnderlyingErrorKey: present")
        }
        if nsError.userInfo[NSDetailedErrorsKey] == nil {
            lines.append(indent(depth) + "NSDetailedErrorsKey: NONE")
        } else {
            lines.append(indent(depth) + "NSDetailedErrorsKey: present")
        }

        for nested in nestedErrors(in: nsError.userInfo, excludingPartialMap: true) {
            inspectNSErrorTree(nested, depth: depth + 1, seen: &seen, into: &lines)
        }
    }

    private static func inspectPartialItem(
        itemID: AnyHashable,
        itemError: Error,
        depth: Int,
        seen: inout Set<ObjectIdentifier>,
        into lines: inout [String]
    ) {
        let nestedNS = itemError as NSError
        let nestedCK = asCKError(itemError)
        lines.append(indent(depth) + "Partial failure item:")
        lines.append(indent(depth) + "Item identifier: \(describeItemID(itemID))")
        lines.append(indent(depth) + "Item identifier type: \(String(describing: type(of: itemID.base)))")
        lines.append(indent(depth) + "Nested error type: \(String(describing: type(of: itemError)))")
        lines.append(indent(depth) + "Nested NSError domain: \(nestedNS.domain)")
        lines.append(indent(depth) + "Nested NSError code: \(nestedNS.code)")
        if let nestedCK {
            lines.append(
                indent(depth)
                    + "Nested CKError code/name: \(nestedCK.code.rawValue) (\(CloudSyncErrorFormatting.ckCodeName(nestedCK.code)))"
            )
        } else if nestedNS.domain == CKErrorDomain {
            let code = CKError.Code(rawValue: nestedNS.code)
            lines.append(
                indent(depth)
                    + "Nested CKError code/name: \(nestedNS.code) (\(CloudSyncErrorFormatting.ckCodeName(code)))"
            )
        } else {
            lines.append(indent(depth) + "Nested CKError code/name: NONE")
        }
        lines.append(indent(depth) + "Description: \(nestedNS.localizedDescription)")
        lines.append(indent(depth) + "UserInfo:")
        appendUserInfoPairs(nestedNS.userInfo, indent: indent(depth) + "  ", into: &lines)
        inspectNSErrorTree(itemError, depth: depth + 1, seen: &seen, into: &lines)
    }

    private static func inspectCKError(_ ckError: CKError, nsError: NSError, depth: Int, into lines: inout [String]) {
        inspectCKErrorFields(
            code: ckError.code,
            nsError: nsError,
            typedCKError: ckError,
            depth: depth,
            into: &lines
        )
    }

    private static func inspectCKErrorFields(
        code: CKError.Code?,
        nsError: NSError,
        typedCKError: CKError?,
        depth: Int,
        into lines: inout [String]
    ) {
        let numeric = code?.rawValue ?? nsError.code
        lines.append(indent(depth) + "CKError numeric code: \(numeric)")
        lines.append(indent(depth) + "CKError readable code: \(CloudSyncErrorFormatting.ckCodeName(code))")
        lines.append(indent(depth) + "Localized description: \(nsError.localizedDescription)")

        if let seconds = typedCKError?.retryAfterSeconds {
            lines.append(indent(depth) + "Retry after: \(seconds)s")
        } else if let number = nsError.userInfo[retryAfterKey] as? NSNumber {
            lines.append(indent(depth) + "Retry after: \(number.doubleValue)s")
        } else {
            lines.append(indent(depth) + "Retry after: NONE")
        }
    }

    private static func inspectCloudKitUserInfoKeys(_ userInfo: [String: Any], depth: Int, into lines: inout [String]) {
        let keys: [(String, String)] = [
            (partialErrorsKey, "CKPartialErrorsByItemIDKey"),
            (ancestorRecordKey, "CKRecordChangedErrorAncestorRecordKey"),
            (clientRecordKey, "CKRecordChangedErrorClientRecordKey"),
            (serverRecordKey, "CKRecordChangedErrorServerRecordKey"),
            (retryAfterKey, "CKErrorRetryAfterKey"),
        ]
        for (key, label) in keys {
            if let value = userInfo[key] {
                lines.append(indent(depth) + "\(label): present (\(describeSafely(value)))")
            } else {
                lines.append(indent(depth) + "\(label): absent")
            }
        }
    }

    private static func asCKError(_ error: Error) -> CKError? {
        if let ckError = error as? CKError {
            return ckError
        }
        let nsError = error as NSError
        guard nsError.domain == CKErrorDomain else { return nil }
        return CKError(_nsError: nsError)
    }

    private static func partialErrorMap(from nsError: NSError) -> [AnyHashable: Error]? {
        if let ckError = asCKError(nsError), let partial = ckError.partialErrorsByItemID, !partial.isEmpty {
            return partial
        }
        return dictionaryOfErrors(nsError.userInfo[partialErrorsKey])
    }

    private static func dictionaryOfErrors(_ value: Any?) -> [AnyHashable: Error]? {
        if let map = value as? [AnyHashable: Error], !map.isEmpty { return map }
        if let map = value as? [AnyHashable: NSError], !map.isEmpty {
            return map.mapValues { $0 as Error }
        }
        if let map = value as? NSDictionary, map.count > 0 {
            var result: [AnyHashable: Error] = [:]
            for (key, item) in map {
                guard let itemError = item as? NSError else { continue }
                if let hashable = key as? AnyHashable {
                    result[hashable] = itemError
                } else {
                    result[String(describing: key)] = itemError
                }
            }
            return result.isEmpty ? nil : result
        }
        return nil
    }

    private static func nestedErrors(in userInfo: [String: Any], excludingPartialMap: Bool) -> [Error] {
        var nested: [Error] = []
        var seen = Set<ObjectIdentifier>()

        func appendError(_ error: Error) {
            let identity = ObjectIdentifier(error as NSError)
            guard seen.insert(identity).inserted else { return }
            nested.append(error)
        }

        for (key, value) in userInfo {
            if excludingPartialMap, key == partialErrorsKey { continue }
            collectErrors(from: value, into: appendError)
        }
        return nested
    }

    private static func collectErrors(from value: Any, into append: (Error) -> Void) {
        if let error = value as? NSError {
            append(error)
            return
        }
        if let error = value as? Error, !(value is CKRecord), !(value is CKRecord.ID) {
            append(error)
            return
        }
        if let list = value as? [Error] {
            list.forEach(append)
            return
        }
        if let list = value as? [NSError] {
            list.forEach { append($0) }
            return
        }
        if let list = value as? NSArray {
            for item in list {
                collectErrors(from: item, into: append)
            }
            return
        }
        if let map = value as? [AnyHashable: Error] {
            map.values.forEach(append)
            return
        }
        if let map = value as? [AnyHashable: NSError] {
            map.values.forEach { append($0) }
            return
        }
        if let map = value as? [String: Any] {
            for item in map.values {
                collectErrors(from: item, into: append)
            }
            return
        }
        if let map = value as? NSDictionary {
            for item in map.allValues {
                collectErrors(from: item, into: append)
            }
        }
    }

    private static func appendUserInfoPairs(_ userInfo: [String: Any], indent: String, into lines: inout [String]) {
        if userInfo.isEmpty {
            lines.append(indent + "(empty)")
            return
        }
        for key in userInfo.keys.sorted() {
            lines.append(indent + "\(key) = \(describeSafely(userInfo[key] as Any))")
        }
    }

    private static func describeItemID(_ itemID: AnyHashable) -> String {
        if let recordID = itemID as? CKRecord.ID ?? itemID.base as? CKRecord.ID {
            return "CKRecord.ID recordName=\(recordID.recordName) zone=\(recordID.zoneID.zoneName) owner=\(recordID.zoneID.ownerName)"
        }
        if let zoneID = itemID as? CKRecordZone.ID ?? itemID.base as? CKRecordZone.ID {
            return "CKRecordZone.ID zone=\(zoneID.zoneName) owner=\(zoneID.ownerName)"
        }
        return String(describing: itemID)
    }

    private static func describeSafely(_ value: Any) -> String {
        if let record = value as? CKRecord {
            return "CKRecord type=\(record.recordType) id=\(record.recordID.recordName) zone=\(record.recordID.zoneID.zoneName)"
        }
        if let recordID = value as? CKRecord.ID {
            return "CKRecord.ID recordName=\(recordID.recordName) zone=\(recordID.zoneID.zoneName)"
        }
        if let zoneID = value as? CKRecordZone.ID {
            return "CKRecordZone.ID zone=\(zoneID.zoneName)"
        }
        if let data = value as? Data {
            return "<\(data.count) bytes>"
        }
        if let error = value as? NSError {
            return "\(error.domain) \(error.code): \(error.localizedDescription)"
        }
        if dictionaryOfErrors(value) != nil {
            return "<partial error map>"
        }
        let raw = String(describing: value)
        return redactUnsafelyLarge(raw)
    }

    private static func redactUnsafelyLarge(_ raw: String) -> String {
        if raw.count <= maxUserInfoValueLength { return raw }
        return String(raw.prefix(maxUserInfoValueLength)) + "…"
    }

    private static func indent(_ depth: Int) -> String {
        String(repeating: "  ", count: depth)
    }

    private static func formatDate(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return SyncDebugFormatting.logDateFormatter.string(from: date)
    }
}
