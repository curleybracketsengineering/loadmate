import Foundation

enum Formatters {
    static let oneDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    static func kg(_ value: Double) -> String {
        let formatted = oneDecimal.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) kg"
    }
}
