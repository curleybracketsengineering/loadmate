import Foundation
import UIKit
import Vision

struct DrivingLicenceSuggestions: Equatable {
    var surname: String = ""
    var forenames: String = ""
    var dateOfBirth: String = ""
    var address: String = ""
    var driverNumber: String = ""
    var expiryDate: String = ""

    var fullName: String {
        [forenames, surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var hasUsefulFields: Bool {
        !fullName.isEmpty || !address.isEmpty || !driverNumber.isEmpty
    }
}

typealias UKDrivingLicenceSuggestions = DrivingLicenceSuggestions

/// Parses a photographed UK or EU-model photocard driving licence into exchangeable contact fields.
/// Field numbers follow Directive 2006/126/EC (1 surname, 2 forenames, 3 DOB, 5 number, 8 address optional).
enum DrivingLicenceOCR {
    private static let titleTokens: Set<String> = [
        "MR", "MRS", "MISS", "MS", "MX", "DR", "SIR", "LADY", "LORD",
        "M", "MME", "MLLE", "HERR", "FRAU", "FR", "SR", "SRA", "SIG", "SIG.RA"
    ]

    /// Words that mean “Driving Licence” (or close OCR) in common EU languages.
    private static let licenceHeaderFragments: [String] = [
        "DRIVING LICENCE",
        "DRIVING LICENSE",
        "PERMIS DE CONDUIRE",
        "PERMIS DE CONDUCERE",
        "PERMISO DE CONDUCCION",
        "PERMISO DE CONDUCCIÓN",
        "PATENTE DI GUIDA",
        "FUHRERSCHEIN",
        "FÜHRERSCHEIN",
        "FUEHRERSCHEIN",
        "RIJBEWIJS",
        "CARTA DE CONDUCAO",
        "CARTA DE CONDUÇÃO",
        "PRAWO JAZDY",
        "KORKORT",
        "KÖRKORT",
        "KOREKORT",
        "KØREKORT",
        "AJOKORTTI",
        "RIDICSKY",
        "CEADUNAS",
        "CEADÚNAS",
        "VOZACKA",
        "VOZAČKA",
        "VODICSKY",
        "VODIČSKÝ",
        "CONDUCERE",
        "CONDUCIR"
    ]

    private static let countryCodeTokens: Set<String> = [
        "UK", "GB", "EU", "D", "F", "I", "E", "NL", "B", "L", "A", "P", "PL",
        "CZ", "SK", "HU", "RO", "BG", "HR", "SI", "SE", "FI", "DK", "EE",
        "LV", "LT", "IE", "MT", "CY", "GR", "EL", "PT", "ES", "IT", "DE", "FR", "BE", "AT"
    ]

    static func analyze(image: UIImage) async throws -> DrivingLicenceSuggestions {
        let lines = try await recognizeLines(in: image)
        return suggestions(from: lines)
    }

    static func suggestions(from rawLines: [String]) -> DrivingLicenceSuggestions {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result = DrivingLicenceSuggestions()
        result.driverNumber = firstLicenceNumber(in: lines) ?? ""
        result.expiryDate = firstLabeledDate(in: lines, labels: ["4B", "4B."]) ?? ""
        result.dateOfBirth = firstDateOfBirth(in: lines) ?? ""
        result.address = firstAddress(in: lines)

        let looksLikeLicence = containsLicenceHeader(in: lines)
            || !result.driverNumber.isEmpty
            || hasEUModelFieldStructure(in: lines)
            || (!result.address.isEmpty && (containsUKPostcode(result.address) || containsEuropeanPostcode(result.address)))

        guard looksLikeLicence else {
            // Without a licence cue, do not invent names from unrelated OCR noise.
            var sparse = DrivingLicenceSuggestions()
            sparse.address = result.address
            sparse.driverNumber = result.driverNumber
            sparse.expiryDate = result.expiryDate
            sparse.dateOfBirth = result.dateOfBirth
            return sparse
        }

        // Prefer explicit numbered fields when Vision keeps value on the same line.
        applyInlineNumberedNameFields(lines, into: &result)
        // Then orphan labels between values (common on UK and many EU cards).
        applyAdjacentNumberedNameFields(lines, into: &result)

        // UK cards often include MR/MRS; many EU cards do not.
        if result.forenames.isEmpty || result.surname.isEmpty, let titled = firstTitledNameLine(in: lines) {
            if result.forenames.isEmpty {
                result.forenames = cleanForenames(titled.line)
            }
            if result.surname.isEmpty, let surname = surnameBefore(index: titled.index, in: lines) {
                result.surname = surname
            }
        }

        if result.surname.isEmpty {
            result.surname = firstStandaloneSurname(in: lines, excludingForenames: result.forenames)
        }

        if result.forenames.isEmpty, let forenames = firstUntitledForenames(in: lines, surname: result.surname) {
            result.forenames = forenames
        }

        return result
    }

    // MARK: - Vision

    private static func recognizeLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            func resumeOnce(_ body: (CheckedContinuation<[String], Error>) -> Void) {
                guard !didResume else { return }
                didResume = true
                body(continuation)
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resumeOnce { $0.resume(throwing: error) }
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation] ?? []).sorted { lhs, rhs in
                    let left = lhs.boundingBox
                    let right = rhs.boundingBox
                    if abs(left.midY - right.midY) > 0.02 {
                        return left.midY > right.midY
                    }
                    return left.minX < right.minX
                }
                let lines = observations.compactMap {
                    $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
                resumeOnce { $0.resume(returning: lines) }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = [
                "en-GB", "en-US", "fr-FR", "de-DE", "it-IT", "es-ES", "nl-NL", "pt-PT", "pl-PL"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce { $0.resume(throwing: error) }
            }
        }
    }

    // MARK: - Licence detection

    private static func containsLicenceHeader(in lines: [String]) -> Bool {
        lines.contains { line in
            let upper = foldDiacritics(line.uppercased())
            return licenceHeaderFragments.contains { upper.contains(foldDiacritics($0)) }
        }
    }

    private static func hasEUModelFieldStructure(in lines: [String]) -> Bool {
        var saw1 = false
        var saw2 = false
        var saw4 = false
        var saw5 = false
        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("1.") || upper == "1" || upper == "1." { saw1 = true }
            if upper.hasPrefix("2.") || upper == "2" || upper == "2." { saw2 = true }
            if upper.contains("4A") || upper.contains("4B") || upper.hasPrefix("4.") { saw4 = true }
            if upper.hasPrefix("5.") || upper == "5" || upper == "5." { saw5 = true }
        }
        return (saw1 && saw2 && saw4) || (saw1 && saw2 && saw5)
    }

    // MARK: - Names

    private static func applyInlineNumberedNameFields(_ lines: [String], into result: inout DrivingLicenceSuggestions) {
        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("1.") {
                let value = stripLeadingFieldNumber(line)
                guard !value.isEmpty else { continue }
                if hasTitleToken(value) {
                    if result.forenames.isEmpty {
                        result.forenames = cleanForenames(value)
                    }
                } else if !looksLikeDateLine(value) {
                    if result.surname.isEmpty || result.surname == cleanName(value) {
                        result.surname = cleanName(value)
                    }
                }
            }
            if upper.hasPrefix("2.") {
                let value = stripLeadingFieldNumber(line)
                guard !value.isEmpty, !looksLikeDateLine(value) else { continue }
                if result.forenames.isEmpty {
                    result.forenames = cleanForenames(value)
                }
            }
        }
    }

    private static func applyAdjacentNumberedNameFields(_ lines: [String], into result: inout DrivingLicenceSuggestions) {
        for index in lines.indices {
            let label = lines[index].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard looksLikeOrphanFieldLabel(lines[index]) else { continue }
            guard index + 1 < lines.count else { continue }
            let next = lines[index + 1]
            guard !looksLikeOrphanFieldLabel(next), !looksLikeJunkHeader(next) else { continue }

            if label == "1" || label == "1." {
                if hasTitleToken(next) {
                    if result.forenames.isEmpty {
                        result.forenames = cleanForenames(next)
                    }
                    if result.surname.isEmpty, let surname = surnameBefore(index: index, in: lines) {
                        result.surname = surname
                    }
                } else if !looksLikeDateLine(next), result.surname.isEmpty {
                    result.surname = cleanName(stripLeadingFieldNumber(next))
                }
            }

            if label == "2" || label == "2." {
                if looksLikeDateLine(next) {
                    if result.dateOfBirth.isEmpty {
                        result.dateOfBirth = firstFlexibleDate(in: next) ?? ""
                    }
                } else if result.forenames.isEmpty {
                    result.forenames = cleanForenames(next)
                }
            }
        }
    }

    private static func firstTitledNameLine(in lines: [String]) -> (index: Int, line: String)? {
        for (index, line) in lines.enumerated() {
            guard hasTitleToken(line), isMostlyLetters(line), !looksLikeJunkHeader(line) else { continue }
            return (index, line)
        }
        return nil
    }

    private static func surnameBefore(index: Int, in lines: [String]) -> String? {
        guard index > 0 else { return nil }
        for probe in stride(from: index - 1, through: 0, by: -1) {
            let line = lines[probe]
            if looksLikeOrphanFieldLabel(line) { continue }
            if looksLikeJunkHeader(line) { continue }
            if looksLikeDateLine(line) || isLikelyLicenceNumberLine(line) || isLikelyCategoriesLine(line) {
                continue
            }
            if looksLikeAddressStart(line) || containsUKPostcode(line) || containsEuropeanPostcode(line) {
                continue
            }
            let cleaned = cleanName(stripLeadingFieldNumber(line))
            guard !cleaned.isEmpty, isMostlyLetters(cleaned), !hasTitleToken(cleaned) else { continue }
            if cleaned.split(separator: " ").count <= 2 {
                return cleaned
            }
        }
        return nil
    }

    private static func firstStandaloneSurname(in lines: [String], excludingForenames: String) -> String {
        let excluded = excludingForenames.uppercased()
        for line in lines {
            if looksLikeJunkHeader(line) || looksLikeOrphanFieldLabel(line) { continue }
            if hasTitleToken(line) || looksLikeDateLine(line) { continue }
            if isLikelyLicenceNumberLine(line) || isLikelyCategoriesLine(line) { continue }
            if looksLikeAddressStart(line) || containsUKPostcode(line) || containsEuropeanPostcode(line) {
                continue
            }
            if isCountryCodeOnly(line) { continue }
            let cleaned = cleanName(stripLeadingFieldNumber(line))
            guard !cleaned.isEmpty,
                  cleaned.uppercased() != excluded,
                  isMostlyLetters(cleaned),
                  cleaned.split(separator: " ").count == 1
            else { continue }
            return cleaned
        }
        return ""
    }

    private static func firstUntitledForenames(in lines: [String], surname: String) -> String? {
        for line in lines {
            if looksLikeJunkHeader(line) || looksLikeOrphanFieldLabel(line) { continue }
            if looksLikeDateLine(line) || isLikelyLicenceNumberLine(line) || isLikelyCategoriesLine(line) {
                continue
            }
            if isCountryCodeOnly(line) { continue }
            let cleaned = cleanForenames(line)
            guard !cleaned.isEmpty,
                  cleaned.uppercased() != surname.uppercased(),
                  cleaned.split(separator: " ").count >= 2
            else { continue }
            return cleaned
        }
        return nil
    }

    // MARK: - Address / dates / licence number

    private static func firstAddress(in lines: [String]) -> String {
        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.hasPrefix("8.") || upper == "8" || upper == "8." {
                var parts: [String] = []
                let inline = stripLeadingFieldNumber(line)
                var cursor = index
                if !inline.isEmpty {
                    parts.append(inline)
                    cursor = index + 1
                } else {
                    cursor = index + 1
                }
                while cursor < lines.count {
                    let candidate = lines[cursor]
                    if looksLikeOrphanFieldLabel(candidate) || startsWithOtherFieldNumber(candidate) {
                        break
                    }
                    if isLikelyCategoriesLine(candidate) || isLikelyLicenceNumberLine(candidate) || looksLikeJunkHeader(candidate) {
                        break
                    }
                    let stripped = stripLeadingFieldNumber(candidate)
                    if !stripped.isEmpty {
                        parts.append(stripped)
                    }
                    cursor += 1
                    if parts.count >= 3 { break }
                }
                let joined = cleanAddress(parts.joined(separator: ", "))
                if !joined.isEmpty { return joined }
            }
        }

        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.contains("4A") || upper.contains("4B") || upper.hasPrefix("5.") { continue }
            let stripped = stripLeadingFieldNumber(line)
            guard looksLikeAddressStart(stripped), !looksLikeDateLine(stripped) else { continue }
            var parts = [stripped]
            if index + 1 < lines.count {
                let next = stripLeadingFieldNumber(lines[index + 1])
                if containsUKPostcode(next) || containsEuropeanPostcode(next) || looksLikeTownLine(next) {
                    parts.append(next)
                }
            }
            return cleanAddress(parts.joined(separator: ", "))
        }
        return ""
    }

    private static func firstDateOfBirth(in lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.hasPrefix("3.") {
                if let date = firstFlexibleDate(in: stripLeadingFieldNumber(line)) {
                    return date
                }
            }
            if looksLikeOrphanFieldLabel(line), ["2", "2.", "3", "3."].contains(upper), index + 1 < lines.count {
                if let date = firstFlexibleDate(in: lines[index + 1]) {
                    return date
                }
            }
            if looksLikeDateLine(line),
               let date = firstFlexibleDate(in: line),
               !upper.contains("4A"),
               !upper.contains("4B") {
                if line.split(separator: " ").count >= 2 || index > 0 {
                    return date
                }
            }
        }
        return nil
    }

    private static func firstLabeledDate(in lines: [String], labels: [String]) -> String? {
        for line in lines {
            let upper = line.uppercased()
            guard let label = labels.first(where: { upper.contains($0) }) else { continue }
            // Prefer the date that appears after the label (e.g. "4a. … 4b. 10/10/2034").
            if let labelRange = upper.range(of: label),
               let date = firstFlexibleDate(in: String(line[labelRange.lowerBound...])) {
                return date
            }
            if let date = firstFlexibleDate(in: line) {
                return date
            }
        }
        return nil
    }

    private static func firstLicenceNumber(in lines: [String]) -> String? {
        // Prefer explicit field 5.
        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.hasPrefix("5.") {
                let inline = stripLeadingFieldNumber(line)
                if let match = licenceNumberCandidate(from: inline) {
                    return match
                }
                if index + 1 < lines.count, let match = licenceNumberCandidate(from: lines[index + 1]) {
                    return match
                }
            }
            if looksLikeOrphanFieldLabel(line), ["5", "5."].contains(upper), index + 1 < lines.count {
                if let match = licenceNumberCandidate(from: lines[index + 1]) {
                    return match
                }
            }
        }

        // UK driver numbers are distinctive enough to accept without a field label.
        for line in lines {
            let tokens = line.uppercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            for token in tokens {
                if let match = ukDriverNumberMatch(in: token) {
                    return match
                }
            }
        }
        return nil
    }

    private static func licenceNumberCandidate(from raw: String) -> String? {
        let tokens = raw.uppercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        for token in tokens {
            if let uk = ukDriverNumberMatch(in: token) {
                return uk
            }
        }
        // EU licence numbers vary widely; accept a solid alphanumeric token from field 5.
        let compact = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard compact.count >= 5, compact.count <= 20, compact.contains(where: \.isNumber) else {
            return nil
        }
        // Avoid treating dates as licence numbers.
        if firstFlexibleDate(in: raw) != nil { return nil }
        return compact
    }

    private static func ukDriverNumberMatch(in compact: String) -> String? {
        let pattern = #"^[A-Z9]{5}\d{6}[A-Z]{2}\d[A-Z]{2}$"#
        guard compact.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return compact
    }

    private static func isLikelyLicenceNumberLine(_ line: String) -> Bool {
        if ukDriverNumberMatch(in: line.uppercased().filter { $0.isLetter || $0.isNumber }) != nil {
            return true
        }
        let upper = line.uppercased()
        return upper.hasPrefix("5.") || upper == "5" || upper == "5."
    }

    // MARK: - Cleaning / predicates

    private static func cleanForenames(_ raw: String) -> String {
        let tokens = stripLeadingFieldNumber(raw)
            .uppercased()
            .split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "-" })
            .map(String.init)
            .filter { !titleTokens.contains($0) }
        return tokens.joined(separator: " ")
    }

    private static func cleanName(_ raw: String) -> String {
        stripLeadingFieldNumber(raw)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanAddress(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"\s*,\s*"#, with: ", ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines))
    }

    private static func stripLeadingFieldNumber(_ raw: String) -> String {
        raw.replacingOccurrences(
            of: #"^(?:[1-9]|4[abc]|5|8|9)\.\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasTitleToken(_ line: String) -> Bool {
        let tokens = line.uppercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        return tokens.contains { titleTokens.contains($0) }
    }

    private static func looksLikeOrphanFieldLabel(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.range(of: #"^([1-9]|4[ABC]|8|9)\.?$"#, options: .regularExpression) != nil
    }

    private static func startsWithOtherFieldNumber(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.range(of: #"^([1-79]|4[ABC]|9)\."#, options: .regularExpression) != nil
    }

    private static func looksLikeJunkHeader(_ line: String) -> Bool {
        let upper = foldDiacritics(line.uppercased())
        if licenceHeaderFragments.contains(where: { upper.contains(foldDiacritics($0)) }) {
            return true
        }
        if upper.contains("UNITED KINGDOM") || upper == "DVLA" {
            return true
        }
        if isCountryCodeOnly(line) {
            return true
        }
        // Ghost expiry imprint like "OCT28" on UK cards.
        if upper.range(of: #"^[A-Z]{3}\d{2}$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func isCountryCodeOnly(_ line: String) -> Bool {
        countryCodeTokens.contains(line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    private static func isLikelyCategoriesLine(_ line: String) -> Bool {
        let upper = line.uppercased()
        return upper.hasPrefix("9.")
            || upper.contains("AM/A/")
            || upper.contains("/B1/B/")
            || upper.range(of: #"\bAM\b.*\bB\b"#, options: .regularExpression) != nil
    }

    private static func looksLikeAddressStart(_ line: String) -> Bool {
        let trimmed = stripLeadingFieldNumber(line)
        guard let first = trimmed.first, first.isNumber else { return false }
        // Require a street-like token after the number so dates like "10/10/2019" are ignored.
        let tokens = trimmed.split(separator: " ")
        guard tokens.count >= 2 else { return false }
        return tokens.dropFirst().contains { token in
            token.contains { $0.isLetter }
        }
    }

    private static func looksLikeTownLine(_ line: String) -> Bool {
        containsUKPostcode(line)
            || containsEuropeanPostcode(line)
            || (!line.contains { $0.isNumber } && line.split(separator: " ").count <= 4)
    }

    private static func containsUKPostcode(_ line: String) -> Bool {
        line.uppercased().range(
            of: #"\b[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func containsEuropeanPostcode(_ line: String) -> Bool {
        let upper = line.uppercased()
        // FR/DE/IT-style 5-digit, NL "1234 AB", PL "12-345", generic letter+digit mixes.
        return upper.range(of: #"\b\d{4,5}\b"#, options: .regularExpression) != nil
            || upper.range(of: #"\b\d{4}\s*[A-Z]{2}\b"#, options: .regularExpression) != nil
            || upper.range(of: #"\b\d{2}-\d{3}\b"#, options: .regularExpression) != nil
    }

    private static func looksLikeDateLine(_ line: String) -> Bool {
        firstFlexibleDate(in: line) != nil
    }

    private static func isMostlyLetters(_ line: String) -> Bool {
        let letters = line.filter { $0.isLetter }
        let digits = line.filter { $0.isNumber }
        return letters.count >= 2 && digits.isEmpty
    }

    private static func firstFlexibleDate(in line: String) -> String? {
        // DD.MM.YYYY / DD/MM/YYYY / DD-MM-YYYY
        guard let match = line.range(
            of: #"\b\d{2}[./-]\d{2}[./-]\d{4}\b"#,
            options: .regularExpression
        ) else {
            return nil
        }
        return String(line[match])
    }

    private static func foldDiacritics(_ string: String) -> String {
        string.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }
}

typealias UKDrivingLicenceOCR = DrivingLicenceOCR
