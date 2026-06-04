import Foundation

/// Typical UK caravan kit for the Load starter kit (estimates — user can edit after loading).
enum CaravanStarterKit {
    struct Entry {
        let name: String
        let weightKg: Double
        let zone: LoadZone
        let quantity: Int
    }

    static let entries: [Entry] = [
        Entry(name: "Awning", weightKg: 25, zone: .front, quantity: 1),
        Entry(name: "Kitchen box", weightKg: 20, zone: .middle, quantity: 1),
        Entry(name: "Food / cool box", weightKg: 15, zone: .middle, quantity: 1),
        Entry(name: "Bedding", weightKg: 12, zone: .middle, quantity: 1),
        Entry(name: "Camping chair", weightKg: 4.5, zone: .middle, quantity: 2),
        Entry(name: "Outdoor table", weightKg: 10, zone: .rear, quantity: 1),
        Entry(name: "Clothes holdall", weightKg: 12, zone: .rear, quantity: 1),
        Entry(name: "Tool kit", weightKg: 6, zone: .rear, quantity: 1),
        Entry(name: "BBQ", weightKg: 15, zone: .rear, quantity: 1),
    ]

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
