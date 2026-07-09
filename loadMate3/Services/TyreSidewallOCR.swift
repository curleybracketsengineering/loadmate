import Foundation
import UIKit
import Vision

struct TyreSidewallSuggestions: Identifiable {
    let id = UUID()
    var manufacturer: String?
    var modelName: String?
    var tyreSize: String?
    var loadIndex: String?
    var speedRating: String?
    var dateCode: String?
    var confidenceNotes: [String] = []

    var hasAnySuggestion: Bool {
        manufacturer != nil
            || modelName != nil
            || tyreSize != nil
            || loadIndex != nil
            || speedRating != nil
            || dateCode != nil
    }
}

enum TyreSidewallOCR {
    private static let knownManufacturers: [String] = [
        "MICHELIN", "CONTINENTAL", "GOODYEAR", "PIRELLI", "BRIDGESTONE",
        "DUNLOP", "HANKOOK", "YOKOHAMA", "TOYO", "BFGOODRICH",
        "KUMHO", "FALKEN", "NEXEN", "MAXXIS", "AVON", "UNIROYAL",
        "VREDESTEIN", "COOPER", "GENERAL", "FIRESTONE", "GT RADIAL",
        "MATADOR", "DEBICA", "SEMPERIT", "BARUM", "TRIANGLE"
    ]

    static func analyze(photo: TyrePhoto, vehicleID: UUID) async throws -> TyreSidewallSuggestions {
        guard let image = TyrePhotoStore.loadImage(for: photo, vehicleID: vehicleID) else {
            return TyreSidewallSuggestions(confidenceNotes: ["Photo could not be loaded on this device."])
        }
        let lines = try await recognizeLines(in: image)
        return suggestions(from: lines)
    }

    static func recognizeLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func suggestions(from rawLines: [String], now: Date = Date()) -> TyreSidewallSuggestions {
        let lines = rawLines
            .map { normalizedLine($0) }
            .filter { !$0.isEmpty }

        var suggestions = TyreSidewallSuggestions()
        var notes: [String] = []

        if let dateCode = firstValidDateCode(in: lines, now: now) {
            suggestions.dateCode = dateCode
            notes.append("Manufacture date code recognised. Please confirm against the sidewall before saving.")
        }

        if let tyreSize = firstTyreSize(in: lines) {
            suggestions.tyreSize = tyreSize
            notes.append("Tyre size recognised from the sidewall photo.")
        }

        if let loadAndSpeed = firstLoadAndSpeed(in: lines) {
            suggestions.loadIndex = loadAndSpeed.loadIndex
            suggestions.speedRating = loadAndSpeed.speedRating
            notes.append("Load index and speed rating recognised from the sidewall photo.")
        }

        if let manufacturer = firstManufacturer(in: lines) {
            suggestions.manufacturer = manufacturer.capitalized
            notes.append("Manufacturer recognised from the sidewall photo.")

            if let modelName = firstModelName(in: lines, manufacturer: manufacturer) {
                suggestions.modelName = modelName
                notes.append("Model name may be visible. Please review before applying.")
            }
        }

        if notes.isEmpty {
            notes.append("No reliable sidewall text was recognised. Try a closer photo with the sidewall filling the frame.")
        }

        suggestions.confidenceNotes = notes
        return suggestions
    }

    private static func normalizedLine(_ line: String) -> String {
        line
            .uppercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstValidDateCode(in lines: [String], now: Date) -> String? {
        let pattern = "\\b\\d{2}[ /-]?\\d{2}\\b"
        for line in lines {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            for match in regex.matches(in: line, range: range) {
                guard let matchRange = Range(match.range, in: line) else { continue }
                let candidate = String(line[matchRange])
                if let parsed = TyreSupport.parseDateCode(candidate, now: now) {
                    return parsed.normalized
                }
            }
        }
        return nil
    }

    private static func firstTyreSize(in lines: [String]) -> String? {
        let patterns = [
            "\\b\\d{3}/\\d{2}\\s?[A-Z]{0,2}R\\d{2}[A-Z]{0,3}\\b",
            "\\b\\d{3}/\\d{2}R\\d{2}[A-Z]{0,3}\\b",
            "\\b\\d{3}R\\d{2}[A-Z]{0,3}\\b",
            "\\bLT\\d{3}/\\d{2}R\\d{2}[A-Z]{0,3}\\b"
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      let matchRange = Range(match.range, in: line) else { continue }
                return normalizedTyreSize(String(line[matchRange]))
            }
        }
        return nil
    }

    private static func firstLoadAndSpeed(in lines: [String]) -> (loadIndex: String, speedRating: String)? {
        let patterns = [
            "\\b(\\d{2,3}(?:/\\d{2,3})?)([A-Z])\\b",
            "\\b(\\d{2,3})([A-Z])\\b"
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      match.numberOfRanges >= 3,
                      let loadRange = Range(match.range(at: 1), in: line),
                      let speedRange = Range(match.range(at: 2), in: line) else { continue }

                let loadIndex = String(line[loadRange])
                let speedRating = String(line[speedRange])
                if loadIndex.count >= 2 {
                    return (loadIndex, speedRating)
                }
            }
        }
        return nil
    }

    private static func firstManufacturer(in lines: [String]) -> String? {
        for line in lines {
            for manufacturer in knownManufacturers.sorted(by: { $0.count > $1.count }) where line.contains(manufacturer) {
                return manufacturer
            }
        }
        return nil
    }

    private static func firstModelName(in lines: [String], manufacturer: String) -> String? {
        for line in lines where line.contains(manufacturer) {
            let stripped = line
                .replacingOccurrences(of: manufacturer, with: "")
                .replacingOccurrences(of: "\\bLT?\\d{3}(?:/\\d{2})?\\s?[A-Z]{0,2}R\\d{2}[A-Z]{0,3}\\b", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\b\\d{2,3}(?:/\\d{2,3})?[A-Z]\\b", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\b\\d{2}[ /-]?\\d{2}\\b", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\b(EXTRA LOAD|XL|REINFORCED|CARGO|CAMPING|CP|M\\+S|M&S|ALL SEASON)\\b", with: "", options: .regularExpression)
                .replacingOccurrences(of: "[^A-Z0-9\\- ]", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let rawTokens = stripped.split(separator: " ").map(String.init)
            var tokens: [String] = []
            for token in rawTokens {
                guard token.count > 1 else { continue }
                if token.range(of: "^\\d+$", options: .regularExpression) != nil { continue }
                if token.range(of: "^[A-Z]{1,2}$", options: .regularExpression) != nil,
                   token != "LT" {
                    continue
                }
                tokens.append(token)
            }

            guard !tokens.isEmpty else { continue }
            let candidate = tokens.prefix(4).joined(separator: " ")
            guard candidate.count >= 3 else { continue }
            if knownManufacturers.contains(candidate) { continue }
            return candidate.capitalized
        }
        return nil
    }

    private static func normalizedTyreSize(_ value: String) -> String {
        let compact = value
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .uppercased()

        if compact.hasPrefix("LT") {
            let stripped = compact.dropFirst(2)
            return "LT " + groupedTyreSize(String(stripped))
        }

        return groupedTyreSize(compact)
    }

    private static func groupedTyreSize(_ compact: String) -> String {
        if let match = compact.range(of: #"^\d{3}/\d{2}[A-Z]{0,2}R\d{2}[A-Z]{0,3}$"#, options: .regularExpression) {
            let value = String(compact[match])
            if let slashIndex = value.firstIndex(of: "/"),
               let rIndex = value.firstIndex(of: "R") {
                let prefix = value[..<slashIndex]
                let middle = value[value.index(after: slashIndex)..<rIndex]
                let suffix = value[rIndex...]
                return "\(prefix)/\(middle) \(suffix)"
            }
            return value
        }

        if let match = compact.range(of: #"^\d{3}R\d{2}[A-Z]{0,3}$"#, options: .regularExpression) {
            let value = String(compact[match])
            if let rIndex = value.firstIndex(of: "R") {
                let prefix = value[..<rIndex]
                let suffix = value[rIndex...]
                return "\(prefix) \(suffix)"
            }
            return value
        }

        return compact
    }
}
