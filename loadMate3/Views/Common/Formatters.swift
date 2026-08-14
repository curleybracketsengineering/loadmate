import Foundation

enum Formatters {
    static let oneDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    static func nm(_ value: Double) -> String {
        String(format: "%.0f Nm", value)
    }

    static func kg(_ value: Double) -> String {
        let formatted = oneDecimal.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) kg"
    }

    static func metres(_ value: Double) -> String {
        let formatted = oneDecimal.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) m"
    }

    static func signedKg(_ value: Double) -> String {
        let formatted = oneDecimal.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
        if value < 0 {
            return "-\(formatted) kg"
        }
        if value > 0 {
            return "+\(formatted) kg"
        }
        return "0.0 kg"
    }

    private static let pressureFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let checkedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy 'at' HH:mm"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func pressure(_ valuePSI: Double, unit: PressureUnit) -> String {
        let displayValue = TyreSupport.convertPressure(valuePSI, from: .psi, to: unit)
        let formatted = pressureFormatter.string(from: NSNumber(value: displayValue)) ?? "\(displayValue)"
        return "\(formatted) \(unit.displayName)"
    }

    static func plainPressure(_ value: Double, unit: PressureUnit) -> String {
        let formatted = pressureFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) \(unit.displayName)"
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "Not recorded" }
        return dateFormatter.string(from: value)
    }

    static func dateTime(_ value: Date?) -> String {
        guard let value else { return "Not recorded" }
        return dateTimeFormatter.string(from: value)
    }

    static func checkedAtCaption(_ value: Date) -> String {
        "Checked \(checkedAtFormatter.string(from: value))"
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func currencyInputString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func parseCurrency(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let number = currencyFormatter.number(from: trimmed) {
            return number.doubleValue
        }
        let stripped = trimmed
            .replacingOccurrences(of: currencyFormatter.currencySymbol ?? "", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(stripped)
    }
}
