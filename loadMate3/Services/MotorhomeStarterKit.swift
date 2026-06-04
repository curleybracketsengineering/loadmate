import Foundation

/// Typical UK motorhome kit for the Load starter kit (estimates — user can edit after loading).
enum MotorhomeStarterKit {
    struct Entry {
        let name: String
        let weightKg: Double
        let zone: LoadZone
        let quantity: Int
    }

    static let entries: [Entry] = [
        Entry(name: "Awning", weightKg: 25, zone: .garage, quantity: 1),
        Entry(name: "Kitchen box", weightKg: 20, zone: .central, quantity: 1),
        Entry(name: "Food / cool box", weightKg: 15, zone: .central, quantity: 1),
        Entry(name: "Bedding", weightKg: 12, zone: .back, quantity: 1),
        Entry(name: "Camping chair", weightKg: 4.5, zone: .central, quantity: 2),
        Entry(name: "Outdoor table", weightKg: 8, zone: .garage, quantity: 1),
        Entry(name: "Clothes holdall", weightKg: 12, zone: .back, quantity: 1),
        Entry(name: "Tool kit", weightKg: 6, zone: .garage, quantity: 1),
        Entry(name: "BBQ", weightKg: 12, zone: .garage, quantity: 1),
        Entry(name: "Water load (200 L)", weightKg: 200, zone: .central, quantity: 1),
    ]

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
