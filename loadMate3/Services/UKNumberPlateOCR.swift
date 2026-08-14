import Foundation
import UIKit

enum UKNumberPlateOCR {
    static func analyze(image: UIImage) async throws -> [String] {
        let lines = try await VehiclePlateOCR.recognizeLines(in: image)
        return suggestions(from: lines)
    }

    /// Extracts plausible UK registrations from OCR lines. Adjacent tokens such as `AB12` + `CDE` are joined.
    static func suggestions(from lines: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        func consider(_ raw: String) {
            let normalized = UKRegistration.normalizeForLookup(raw)
            guard UKRegistration.isLikelyCompletePlate(normalized), !seen.contains(normalized) else { return }
            seen.insert(normalized)
            results.append(UKRegistration.displayFormatted(normalized))
        }

        let tokens = lines.flatMap(tokenize)
        for token in tokens {
            consider(token)
        }
        if tokens.count >= 2 {
            for index in 0..<(tokens.count - 1) {
                consider(tokens[index] + tokens[index + 1])
            }
        }
        if tokens.count >= 3 {
            for index in 0..<(tokens.count - 2) {
                consider(tokens[index] + tokens[index + 1] + tokens[index + 2])
            }
        }

        return results
    }

    private static func tokenize(_ line: String) -> [String] {
        line.uppercased()
            .replacingOccurrences(of: "•", with: " ")
            .replacingOccurrences(of: "·", with: " ")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
