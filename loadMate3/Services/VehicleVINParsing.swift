import Foundation

/// Shared VIN / chassis parsing for manufacturer plates and CRiS stickers.
enum VehicleVINParsing {
    static func firstVIN(in lines: [String]) -> String? {
        let normalized = lines.map(normalize).filter { !$0.isEmpty }

        if let labeled = firstLabeledVIN(in: normalized) {
            return labeled
        }

        let bodyFiltered = normalized.filter { !isHabitationBodyLine($0) }

        for line in bodyFiltered {
            if let vin = firstISOVIN(in: line) {
                return vin
            }
        }

        if let spanning = firstISOVINSpanningLines(in: bodyFiltered) {
            return spanning
        }

        return firstNearMissVIN(in: bodyFiltered)
    }

    static func sanitize(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
    }

    /// ISO 3779 forbids I, O and Q. OCR often emits them for 1 and 0.
    static func canonicalize(_ value: String) -> String {
        sanitize(value)
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "Q", with: "0")
    }

    static func isPlausibleVIN(_ value: String, allowShort: Bool = true) -> Bool {
        let vin = sanitize(value)
        guard vin.count >= 11, vin.count <= 17 else { return false }
        if vin.range(of: "[IOQ]", options: .regularExpression) != nil { return false }
        if vin.count == 17 {
            let letters = letterCount(in: vin)
            return (3...12).contains(letters) && !looksLikeTypeApproval(vin)
        }
        return allowShort && letterCount(in: vin) >= 2 && vin.contains(where: \.isNumber)
    }

    // MARK: - Labels

    /// Most specific first. `VIN` is preferred over `CRIS` when both appear.
    private static let vinLabels: [String] = [
        "VEHICLE IDENTIFICATION NUMBER",
        "VEHICLE IDENTIFICATION NO",
        "VEHICLE IDENTIFICATION",
        "FAHRZEUG IDENTIFIZIERUNGSNUMMER",
        "FAHRZEUGIDENTIFIZIERUNGSNUMMER",
        "NUMERO DI IDENTIFICAZIONE DEL VEICOLO",
        "NUMERO DI IDENTIFICAZIONE",
        "NUMERO DE IDENTIFICACION DEL VEHICULO",
        "NUMERO DE IDENTIFICACION",
        "NUMERO D IDENTIFICATION",
        "NO D IDENTIFICATION",
        "N D IDENTIFICATION",
        "IDENTIFICATION NUMBER",
        "IDENTIFICATION NO",
        "IDENTIFICATIENUMMER",
        "IDENTIFIKATIONSNUMMER",
        "NUMER IDENTYFIKACYJNY",
        "NUMER NADWOZIA",
        "NUMERO DO QUADRO",
        "NUMERO DE BASTIDOR",
        "NUMERO DI TELAIO",
        "FAHRGESTELLNUMMER",
        "FAHRGESTELL NR",
        "FAHRGESTELL",
        "CHASSISNUMMER",
        "CHASSIS NUMBER",
        "CHASSIS NO",
        "CHASSINUMMER",
        "CHASSIS",
        "BASTIDOR",
        "TELAIO",
        "VIN NO",
        "VIN",
        "FIN",
        "CRIS NO",
        "CRIS",
        "NUMERO DE SERIE DU VEHICULE",
        "N DE SERIE DU VEHICULE",
        "NUMERO DE SERIE",
        "NO DE SERIE",
        "N DE SERIE",
        "IDENTNR",
        "FZ NR",
        "IDENTIFICATION"
    ]

    private static func isHabitationBodyLine(_ line: String) -> Bool {
        let tokens = [
            "CELLULE", "AUFBAU", "KAROSSERIE", "WOHNKABINE",
            "BODY NUMBER", "BODY NO", "CONVERSION NUMBER", "CONVERSION NO"
        ]
        return tokens.contains(where: { line.contains($0) })
    }

    private static func normalize(_ line: String) -> String {
        line
            .uppercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .uppercased()
            .replacingOccurrences(of: "°", with: " ")
            .replacingOccurrences(of: "º", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "`", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstLabeledVIN(in lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            if isHabitationBodyLine(line) { continue }
            guard let label = vinLabels.first(where: { line.contains($0) }) else { continue }

            if let range = line.range(of: label) {
                let after = String(line[range.upperBound...])
                if let vin = firstVINCandidate(in: after, allowShort: true) {
                    return vin
                }
            }

            for offset in 1...2 where index + offset < lines.count {
                let next = lines[index + offset]
                if isHabitationBodyLine(next) { continue }
                if vinLabels.contains(where: { next.contains($0) }) { continue }
                if let vin = firstVINCandidate(in: next, allowShort: true) {
                    return vin
                }
            }
        }

        return nil
    }

    private static func firstISOVIN(in text: String) -> String? {
        firstVINCandidate(in: text, allowShort: false)
    }

    /// OCR often adds or drops a zero in Fiat-style VINs (`ZFA2500000…`).
    private static func firstNearMissVIN(in lines: [String]) -> String? {
        var candidates: [String] = []
        for line in lines {
            let compact = canonicalize(line)
            guard compact.count >= 16 else { continue }
            if looksLikeTypeApproval(compact), compact.count < 20 { continue }
            candidates.append(contentsOf: nearMissISOCandidates(in: compact))
        }
        return bestVIN(in: candidates, allowShort: false)
    }

    private static func nearMissISOCandidates(in compact: String) -> [String] {
        let chars = Array(compact)
        var windows: [String] = []
        for start in 0..<chars.count where chars[start].isLetter {
            let maxLength = min(19, chars.count - start)
            guard maxLength >= 16 else { continue }
            for length in 16...maxLength {
                windows.append(String(chars[start..<(start + length)]))
            }
        }

        var fitted: [String] = []
        for window in windows {
            fitted.append(contentsOf: fitTo17CharacterVIN(window))
        }
        return fitted
    }

    private static func fitTo17CharacterVIN(_ value: String) -> [String] {
        if value.count == 17 { return [value] }
        if value.count == 18 {
            return variantsByRemovingOneZero(from: value)
        }
        if value.count == 19 {
            return variantsByRemovingOneZero(from: value)
                .flatMap(variantsByRemovingOneZero)
                .filter { $0.count == 17 }
        }
        if value.count == 16 {
            return variantsByInsertingZero(into: value)
        }
        return []
    }

    private static func variantsByRemovingOneZero(from value: String) -> [String] {
        let chars = Array(value)
        return chars.indices.compactMap { index in
            guard chars[index] == "0" else { return nil }
            var next = chars
            next.remove(at: index)
            return String(next)
        }
    }

    private static func variantsByInsertingZero(into value: String) -> [String] {
        let chars = Array(value)
        guard chars.count >= 3 else { return [] }
        return (3...chars.count).map { index in
            var next = chars
            next.insert("0", at: index)
            return String(next)
        }
    }

    private static func firstISOVINSpanningLines(in lines: [String]) -> String? {
        guard lines.count >= 2 else { return nil }

        for start in 0..<(lines.count - 1) {
            for end in (start + 1)...min(start + 2, lines.count - 1) {
                let window = Array(lines[start...end])
                guard isVINFragmentLine(window[0], allowDigitsOnly: false) else { continue }
                guard window.dropFirst().allSatisfy({ isVINFragmentLine($0, allowDigitsOnly: true) }) else {
                    continue
                }
                if let vin = firstISOVIN(in: window.joined(separator: " ")) {
                    return vin
                }
            }
        }

        return nil
    }

    private static func isVINFragmentLine(_ line: String, allowDigitsOnly: Bool) -> Bool {
        if isHabitationBodyLine(line) { return false }
        let compact = sanitize(line)
        guard (4...16).contains(compact.count) else { return false }
        let letters = letterCount(in: compact)
        if letters == 0 {
            return allowDigitsOnly && compact.allSatisfy(\.isNumber)
        }
        guard compact.contains(where: \.isNumber) else { return false }
        let noise = line.replacingOccurrences(of: "[A-Z0-9\\s\\-]", with: "", options: .regularExpression)
        return noise.count <= 3
    }

    private static func firstVINCandidate(in text: String, allowShort: Bool) -> String? {
        var candidates = isoVINCandidates(in: text)
        if allowShort {
            candidates.append(contentsOf: shortCandidates(in: text))
        }
        return bestVIN(in: candidates, allowShort: allowShort)
    }

    private static func isoVINCandidates(in text: String) -> [String] {
        matches(in: text, pattern: #"((?:[A-HJ-NPR-Z0-9IOQ][\s\-]*){17})(?![A-Z0-9IOQ])"#)
            .filter { sanitize($0).contains(where: \.isNumber) }
            .map(canonicalize)
            .filter { $0.count == 17 }
    }

    private static func shortCandidates(in text: String) -> [String] {
        matches(in: text, pattern: #"((?:[A-HJ-NPR-Z0-9IOQ][\s\-]*){11,16})"#)
            .filter { sanitize($0).contains(where: \.isNumber) }
            .map(canonicalize)
            .filter { (11...16).contains($0.count) }
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private static func bestVIN(in candidates: [String], allowShort: Bool) -> String? {
        candidates
            .filter { isPlausibleVIN($0, allowShort: allowShort) }
            .max(by: { score($0) < score($1) })
    }

    private static func score(_ vin: String) -> Int {
        var value = vin.count == 17 ? 20 : 0
        if isoCheckDigitValid(vin) { value += 30 }
        if looksLikeTypeApproval(vin) { value -= 50 }
        if vin.first?.isLetter == true { value += 5 }
        if vin.count >= 2, vin.prefix(2).allSatisfy(\.isLetter) { value += 10 }
        if vin.count == 17, vin.suffix(4).allSatisfy(\.isNumber) { value += 5 }
        value += letterCount(in: vin)
        return value
    }

    private static func looksLikeTypeApproval(_ vin: String) -> Bool {
        if vin.range(of: #"^[EGN]\d"#, options: .regularExpression) != nil { return true }
        if vin.contains("200746") || vin.contains("2001116") || vin.contains("2018858") { return true }
        if vin.contains("70156") || vin.contains("9814") { return true }
        return false
    }

    private static func letterCount(in value: String) -> Int {
        value.filter(\.isLetter).count
    }

    static func isoCheckDigitValid(_ vin: String) -> Bool {
        let vin = canonicalize(vin)
        guard vin.count == 17 else { return false }

        let values: [Character: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7, "H": 8,
            "J": 1, "K": 2, "L": 3, "M": 4, "N": 5, "P": 7, "R": 9,
            "S": 2, "T": 3, "U": 4, "V": 5, "W": 6, "X": 7, "Y": 8, "Z": 9,
            "0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9
        ]
        let weights = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2]

        var sum = 0
        for (index, character) in vin.enumerated() {
            guard let mapped = values[character] else { return false }
            sum += mapped * weights[index]
        }

        let remainder = sum % 11
        let expected = remainder == 10 ? "X" : String(remainder)
        let checkIndex = vin.index(vin.startIndex, offsetBy: 8)
        return String(vin[checkIndex]) == expected
    }
}
