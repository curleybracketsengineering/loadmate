import Foundation
import UIKit
import Vision

struct VehiclePlateSuggestions: Identifiable {
    let id = UUID()
    var vinChassisNumber: String?
    var manufacturer: String?
    var modelName: String?
    var mtplmOrMamKg: Double?
    var miroOrMroKg: Double?
    var hitchOrNoseKg: Double?
    var maxFrontAxleKg: Double?
    var maxRearAxleKg: Double?
    /// Gross train weight / GTM / combination mass. Not tow-bar nose load.
    var gtwKg: Double?
    /// Converter body / cell number (e.g. Rapido N° de cellule).
    var bodyCellNumber: String?
    var tyreSize: String?
    /// Recommended cold pressure from the plate, normalised to PSI.
    var tyrePressurePSI: Double?
    /// Unit shown on the plate for the pressure suggestion (for review display).
    var tyrePressureDisplayUnit: PressureUnit?
    var wheelNutTorqueSteelNm: Double?
    var wheelNutTorqueAlloyNm: Double?
    var confidenceNotes: [String] = []
    /// Mass fields that parsed but fail plausibility checks. Review UI shows them in red, off by default.
    var unlikelyMassFields: Set<VehiclePlateUnlikelyMassField> = []

    var hasAnySuggestion: Bool {
        vinChassisNumber != nil
            || manufacturer != nil
            || modelName != nil
            || mtplmOrMamKg != nil
            || miroOrMroKg != nil
            || hitchOrNoseKg != nil
            || maxFrontAxleKg != nil
            || maxRearAxleKg != nil
            || gtwKg != nil
            || bodyCellNumber != nil
            || tyreSize != nil
            || tyrePressurePSI != nil
            || wheelNutTorqueSteelNm != nil
            || wheelNutTorqueAlloyNm != nil
    }
}

enum VehiclePlateUnlikelyMassField: String, Hashable {
    case mtplmOrMam
    case gtw
    case miro
    case hitchOrNose
    case frontAxle
    case rearAxle
}

enum VehiclePlateOCR {
    /// Laden / axle / train masses. Type-approval fragments like `*0085*` (85 kg) are below this.
    private static let vehicleMassRange: ClosedRange<Double> = 400...10_000
    private static let noseRange: ClosedRange<Double> = 20...350

    static func analyze(image: UIImage) async throws -> VehiclePlateSuggestions {
        let lines = try await recognizeLines(in: image)
        return suggestions(from: lines)
    }

    static func recognizeLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            // Vision may invoke the request callback and also throw from `perform`.
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
                    // Vision origin is bottom-left; higher midY is higher on the plate.
                    if abs(left.midY - right.midY) > 0.02 {
                        return left.midY > right.midY
                    }
                    return left.minX < right.minX
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                resumeOnce { $0.resume(returning: lines) }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-GB", "fr-FR", "de-DE", "it-IT"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce { $0.resume(throwing: error) }
            }
        }
    }

    static func suggestions(from rawLines: [String]) -> VehiclePlateSuggestions {
        let lines = rawLines
            .map { normalizedLine($0) }
            .filter { !$0.isEmpty }

        var suggestions = VehiclePlateSuggestions()
        var notes: [String] = []
        var claimedValues = Set<Double>()

        if let vin = VehicleVINParsing.firstVIN(in: lines) {
            suggestions.vinChassisNumber = vin
            notes.append("VIN / chassis number recognised from the plate photo.")
        }

        if let manufacturer = firstManufacturer(in: lines, vin: suggestions.vinChassisNumber) {
            suggestions.manufacturer = manufacturer
            notes.append("Manufacturer recognised from the plate photo.")

            if let modelName = firstModelName(in: lines, manufacturer: manufacturer) {
                suggestions.modelName = modelName
                notes.append("Model recognised from the plate photo. Please confirm — model text varies by manufacturer.")
            }
        } else if let modelName = firstLabeledModelName(in: lines) {
            suggestions.modelName = modelName
            notes.append("Model recognised from a labelled plate field. Please confirm.")
        }

        if let cell = firstBodyCellNumber(in: lines) {
            suggestions.bodyCellNumber = cell
            notes.append("Body / cell number recognised from the plate photo.")
        }

        if let mtplm = firstMass(
            in: lines,
            labels: Self.mtplmLabels,
            excluding: claimedValues,
            range: vehicleMassRange
        ) {
            suggestions.mtplmOrMamKg = mtplm
            claimedValues.insert(mtplm)
            notes.append("Maximum laden mass (MTPLM / MAM / MTO) recognised from the plate photo.")
        }

        if let miro = firstMass(
            in: lines,
            labels: Self.miroLabels,
            excluding: claimedValues,
            range: vehicleMassRange
        ) {
            suggestions.miroOrMroKg = miro
            claimedValues.insert(miro)
            notes.append("Mass in running order (MIRO / MRO) recognised from the plate photo.")
        }

        if let nose = firstMass(
            in: lines,
            labels: Self.noseLabels,
            excluding: claimedValues,
            range: noseRange
        ) {
            suggestions.hitchOrNoseKg = nose
            claimedValues.insert(nose)
            notes.append("Hitch / nose / coupling load recognised from the plate photo.")
        }

        if let gtw = firstMass(
            in: lines,
            labels: Self.gtwLabels,
            excluding: claimedValues,
            range: vehicleMassRange
        ) {
            suggestions.gtwKg = gtw
            claimedValues.insert(gtw)
            notes.append("Gross train weight (GTW / GTM) recognised from the plate photo.")
        }

        if let front = firstMass(
            in: lines,
            labels: Self.frontAxleLabels,
            excluding: claimedValues,
            range: vehicleMassRange
        ) {
            suggestions.maxFrontAxleKg = front
            claimedValues.insert(front)
            notes.append("Front axle limit recognised from the plate photo.")
        }

        if let rear = firstMass(
            in: lines,
            labels: Self.rearAxleLabels,
            excluding: claimedValues.subtracting([suggestions.maxFrontAxleKg].compactMap { $0 }),
            range: vehicleMassRange
        ) {
            suggestions.maxRearAxleKg = rear
            claimedValues.insert(rear)
            notes.append("Rear axle limit recognised from the plate photo.")
        }

        applyEUStatutoryMasses(
            in: lines,
            to: &suggestions,
            claimedValues: &claimedValues,
            notes: &notes
        )

        if let tyreSize = TyreSidewallOCR.suggestions(from: rawLines).tyreSize {
            suggestions.tyreSize = tyreSize
            notes.append("Tyre size recognised from the plate photo.")
        }

        if let pressure = firstTyrePressure(in: lines) {
            suggestions.tyrePressurePSI = pressure.psi
            suggestions.tyrePressureDisplayUnit = pressure.displayUnit
            notes.append("Tyre pressure recognised from the plate photo.")
        }

        if let steelTorque = firstWheelNutTorque(in: lines, preference: .steel) {
            suggestions.wheelNutTorqueSteelNm = steelTorque
            notes.append("Steel wheel nut torque recognised from the plate photo.")
        }

        if let alloyTorque = firstWheelNutTorque(in: lines, preference: .alloy) {
            suggestions.wheelNutTorqueAlloyNm = alloyTorque
            notes.append("Alloy wheel nut torque recognised from the plate photo.")
        }

        sanitizeImplausibleMasses(&suggestions, notes: &notes)

        if notes.isEmpty {
            notes.append("No reliable plate text was recognised. Try a closer, sharper photo with the whole plate filling the frame.")
        }

        suggestions.confidenceNotes = notes
        return suggestions
    }

    private static func sanitizeImplausibleMasses(
        _ suggestions: inout VehiclePlateSuggestions,
        notes: inout [String]
    ) {
        suggestions.unlikelyMassFields.removeAll()

        func drop(_ note: String, clear: () -> Void) {
            clear()
            if !notes.contains(note) {
                notes.append(note)
            }
        }

        func flag(_ field: VehiclePlateUnlikelyMassField) {
            suggestions.unlikelyMassFields.insert(field)
        }

        if let mam = suggestions.mtplmOrMamKg, !vehicleMassRange.contains(mam) {
            drop("Ignored an implausible maximum laden mass reading.") {
                suggestions.mtplmOrMamKg = nil
            }
        }
        if let gtw = suggestions.gtwKg, !vehicleMassRange.contains(gtw) {
            drop("Ignored an implausible gross train weight reading.") {
                suggestions.gtwKg = nil
            }
        }
        if let miro = suggestions.miroOrMroKg, !vehicleMassRange.contains(miro) {
            drop("Ignored an implausible mass in running order reading.") {
                suggestions.miroOrMroKg = nil
            }
        }
        if let front = suggestions.maxFrontAxleKg, !vehicleMassRange.contains(front) {
            drop("Ignored an implausible front axle reading.") {
                suggestions.maxFrontAxleKg = nil
            }
        }
        if let rear = suggestions.maxRearAxleKg, !vehicleMassRange.contains(rear) {
            drop("Ignored an implausible rear axle reading.") {
                suggestions.maxRearAxleKg = nil
            }
        }

        if let mam = suggestions.mtplmOrMamKg, let gtw = suggestions.gtwKg, gtw <= mam {
            flag(.gtw)
        }
        if let mam = suggestions.mtplmOrMamKg, let miro = suggestions.miroOrMroKg, miro > mam {
            flag(.miro)
        }
        if let mam = suggestions.mtplmOrMamKg, let front = suggestions.maxFrontAxleKg, front > mam * 1.2 {
            flag(.frontAxle)
        }
        if let mam = suggestions.mtplmOrMamKg, let rear = suggestions.maxRearAxleKg, rear > mam * 1.2 {
            flag(.rearAxle)
        }
        if let gtw = suggestions.gtwKg, let front = suggestions.maxFrontAxleKg, front > gtw {
            flag(.frontAxle)
        }
        if let gtw = suggestions.gtwKg, let rear = suggestions.maxRearAxleKg, rear > gtw {
            flag(.rearAxle)
        }
        if let hitch = suggestions.hitchOrNoseKg, let mam = suggestions.mtplmOrMamKg, hitch > mam {
            flag(.hitchOrNose)
        }

        if !suggestions.unlikelyMassFields.isEmpty {
            let note = "Some plated masses look unlikely compared with each other. Check the plate before applying."
            if !notes.contains(note) {
                notes.append(note)
            }
        }
    }

    // MARK: - Labels

    private static let mtplmLabels: [String] = [
        "MAXIMUM TECHNICALLY PERMISSIBLE LADEN MASS",
        "TECHNICALLY PERMISSIBLE MAXIMUM LADEN MASS",
        "TECHNISCH ZULASSIGE MAXIMALE GESAMTMASSE",
        "TECHNISCH ZULÄSSIGE MAXIMALE GESAMTMASSE",
        "MAXIMUM AUTHORISED MASS",
        "MAXIMUM AUTHORIZED MASS",
        "MAXIMUM PERMISSIBLE MASS",
        "MAXIMUM PERMITTED MASS",
        "MASA MAXIMA TECNICAMENTE ADMISIBLE",
        "MASA MAXIMA AUTORIZADA",
        "MASSE TOTALE AUTORISEE",
        "MASSE MAXIMALE TECHNIQUEMENT ADMISSIBLE",
        "TECHNISCH TOELAATBARE MAXIMUMMASSA",
        "MASSA MASSIMA AMMISSIBILE",
        "MTPLM",
        "M.T.P.L.M",
        "MTAC",
        "M.T.A.C",
        "PTAC",
        "P.T.A.C",
        "MAM",
        "MMA",
        "MTO",
        "M.T.O",
        "GROSS VEHICLE MASS",
        "GROSS VEHICLE WEIGHT",
        "GROSS WEIGHT",
        "GROSS MASS",
        "G.V.M",
        "GVM",
        "ZULASSIGE GESAMTMASSE",
        "ZULÄSSIGE GESAMTMASSE",
        "ZUL. GESAMTGEWICHT",
        "ZUL. GESAMTMASSE",
        "ZGG"
    ]

    private static let gtwLabels: [String] = [
        "TECHNICALLY PERMISSIBLE MAXIMUM MASS OF THE COMBINATION",
        "MAXIMUM MASS OF THE COMBINATION",
        "GROSS COMBINATION WEIGHT",
        "GROSS COMBINATION MASS",
        "GROSS TRAIN WEIGHT",
        "GROSS TRAIN MASS",
        "MASA MAXIMA DEL CONJUNTO",
        "MASSE MAXIMALE DE L ENSEMBLE",
        "MASSE DE L ENSEMBLE",
        "MASSE ENSEMBLE",
        "ZULASSIGE ANHANGERMASSE",
        "ZULÄSSIGE ANHÄNGERMASSE",
        "ZULASSIGE ANHANGELAST",
        "ANHANGERLAST",
        "ANHÄNGERLAST",
        "ZUGGEWICHT",
        "P.T.R.A",
        "PTRA",
        "G.T.W",
        "G.T.M",
        "GTW",
        "GTM"
    ]

    private static let miroLabels: [String] = [
        "MASS IN RUNNING ORDER",
        "MASSE EN ORDRE DE MARCHE",
        "MASA EN ORDEN DE MARCHA",
        "MASSA IN ORDINE DI MARCIA",
        "MASSA RIJVAARDIG",
        "RIJKLARE MASSA",
        "MIRO",
        "M.I.R.O",
        "MRO",
        "M.R.O",
        "UNLADEN WEIGHT",
        "UNLADEN MASS",
        "KERB WEIGHT",
        "LEERGEWICHT",
        "LEERMASSE",
        "TARA"
    ]

    private static let noseLabels: [String] = [
        "STATIC VERTICAL LOAD",
        "MAXIMUM STATIC VERTICAL LOAD",
        "VERTICAL LOAD ON COUPLING",
        "COUPLING LOAD",
        "CARGA VERTICAL SOBRE EL ENGANCHE",
        "CARICO VERTICALE SUL GANCIO",
        "CHARGE SUR ROTULE",
        "CHARGE AU TIMON",
        "CHARGE VERTICALE",
        "MAX NOSE WEIGHT",
        "MAXIMUM NOSE WEIGHT",
        "NOSE WEIGHT",
        "NOSEWEIGHT",
        "HITCH LOAD",
        "HITCH LIMIT",
        "MAX HITCH",
        "MAX STUTZLAST",
        "STUETZLAST",
        "STÜTZLAST",
        "STUTZLAST",
        "S MAX"
    ]

    private static let frontAxleLabels: [String] = [
        "TECHNICALLY PERMISSIBLE MAXIMUM MASS ON THE FRONT AXLE",
        "MAXIMUM MASS ON FRONT AXLE",
        "MAX FRONT AXLE",
        "FRONT AXLE MAX",
        "FRONT AXLE",
        "ESSIEU AVANT",
        "ESSIEU AV",
        "ASSE ANTERIORE",
        "EJE DELANTERO",
        "ACHSLAST 1",
        "ACHSE VORN",
        "AXLE 1",
        "ACHSE 1",
        "1ST AXLE",
        "VOORAS",
        "FA MAX"
    ]

    private static let rearAxleLabels: [String] = [
        "TECHNICALLY PERMISSIBLE MAXIMUM MASS ON THE REAR AXLE",
        "MAXIMUM MASS ON REAR AXLE",
        "MAX REAR AXLE",
        "REAR AXLE MAX",
        "REAR AXLE",
        "ESSIEU ARRIERE",
        "ESSIEU AR",
        "ASSE POSTERIORE",
        "EJE TRASERO",
        "ACHSLAST 2",
        "ACHSE HINTEN",
        "AXLE 2",
        "ACHSE 2",
        "2ND AXLE",
        "ACHTERAS",
        "RA MAX"
    ]

    private static let cellLabels: [String] = [
        "NUMERO DE CELLULE",
        "NO DE CELLULE",
        "N DE CELLULE",
        "CELLULE",
        "NUMERO CARROZZERIA",
        "AUFBAUNUMMER",
        "AUFBAU NR",
        "AUFBAU-NR",
        "KAROSSERIE NR",
        "WOHNKABINE",
        "BODY NUMBER",
        "BODY NO",
        "CONVERSION NUMBER",
        "CONVERSION NO",
        "CELL NUMBER",
        "CELL NO"
    ]

    // MARK: - Parsing

    private static func normalizedLine(_ line: String) -> String {
        line
            .uppercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .uppercased()
            .replacingOccurrences(of: "°", with: " ")
            .replacingOccurrences(of: "º", with: " ")
            .replacingOccurrences(of: "KG\\.?$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMass(
        in lines: [String],
        labels: [String],
        excluding: Set<Double>,
        range: ClosedRange<Double>
    ) -> Double? {
        let sortedLabels = labels.sorted { $0.count > $1.count }

        for (index, line) in lines.enumerated() {
            guard let label = sortedLabels.first(where: { line.contains($0) }) else { continue }

            if let value = massNearLabel(in: line, label: label, excluding: excluding, range: range) {
                return value
            }

            // "GTM -" / empty placeholder — do not steal the next labelled field.
            if isExplicitlyBlankMass(after: label, in: line) {
                continue
            }

            // Value often sits on the next OCR line.
            if index + 1 < lines.count,
               !lineHasAnyMassLabel(lines[index + 1]),
               let value = firstMassValue(in: lines[index + 1], excluding: excluding, range: range) {
                return value
            }
        }

        return nil
    }

    private static func massNearLabel(
        in line: String,
        label: String,
        excluding: Set<Double>,
        range: ClosedRange<Double>
    ) -> Double? {
        guard let labelRange = line.range(of: label) else { return nil }
        let after = String(line[labelRange.upperBound...])
        if let value = firstMassValue(in: after, excluding: excluding, range: range) {
            return value
        }
        let before = String(line[..<labelRange.lowerBound])
        return firstMassValue(in: before, excluding: excluding, range: range)
    }

    private static func isExplicitlyBlankMass(after label: String, in line: String) -> Bool {
        guard let range = line.range(of: label) else { return false }
        let rawAfter = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawAfter.isEmpty else { return false }
        let stripped = rawAfter
            .trimmingCharacters(in: CharacterSet(charactersIn: ":#-–—."))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty
    }

    private static func lineHasAnyMassLabel(_ line: String) -> Bool {
        let labels = mtplmLabels + gtwLabels + miroLabels + noseLabels + frontAxleLabels + rearAxleLabels
        return labels.contains(where: { line.contains($0) })
    }

    private static func firstMassValue(
        in text: String,
        excluding: Set<Double>,
        range: ClosedRange<Double>
    ) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{2,5}(?:[.,]\d{1,2})?)\b"#) else {
            return nil
        }
        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: searchRange) {
            guard let matchRange = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[matchRange]).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(raw) else { continue }
            if looksLikeTypeApprovalMassFragment(raw: raw, line: text) { continue }
            let rounded = value.rounded()
            guard range.contains(rounded), !excluding.contains(rounded) else { continue }
            return rounded
        }
        return nil
    }

    // MARK: - EU statutory plate + cell number

    private static func firstBodyCellNumber(in lines: [String]) -> String? {
        let sortedLabels = cellLabels.sorted { $0.count > $1.count }
        for (index, line) in lines.enumerated() {
            guard let label = sortedLabels.first(where: { line.contains($0) }) else { continue }
            if let value = cellValue(after: label, in: line) {
                return value
            }
            if index + 1 < lines.count, let value = cellValue(in: lines[index + 1]) {
                return value
            }
        }
        return nil
    }

    private static func cellValue(after label: String, in line: String) -> String? {
        guard let range = line.range(of: label) else { return cellValue(in: line) }
        return cellValue(in: String(line[range.upperBound...]))
    }

    private static func cellValue(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"([A-Z0-9][A-Z0-9\-]{5,30})"#) else {
            return nil
        }
        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: searchRange) {
            guard let matchRange = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[matchRange])
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            guard candidate.count >= 6 else { continue }
            if VehicleVINParsing.isPlausibleVIN(candidate) { continue }
            if looksLikeTypeApprovalToken(candidate) { continue }
            return candidate
        }
        return nil
    }

    private static func looksLikeTypeApprovalToken(_ value: String) -> Bool {
        let compact = value.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
        if compact.range(of: #"^[EGN]\d"#, options: .regularExpression) != nil { return true }
        if compact.contains("200746") || compact.contains("2001116") || compact.contains("2018858") { return true }
        if compact.contains("70156") || compact.contains("9814") { return true }
        if compact.contains("NKS") || compact.contains("KS0746") || compact.contains("KS18858") { return true }
        return false
    }

    private static func looksLikeTypeApprovalLine(_ line: String) -> Bool {
        if line.range(of: #"\b[EGN]\d{1,2}\s*\*"#, options: .regularExpression) != nil { return true }
        if line.contains("2007/46") || line.contains("2001/116") || line.contains("2018/858") { return true }
        if line.contains("70/156") || line.contains("98/14") { return true }
        if line.contains("KS07/46") || line.contains("KS18/858") || line.contains("NKS") { return true }
        if line.contains("*") && line.range(of: #"\b[EGN]\d{1,2}\b"#, options: .regularExpression) != nil {
            return true
        }
        if line.range(of: #"\*\s*0*\d{2,4}\s*\*"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"\b0\d{3,4}\s*\*\s*\d{2}\b"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"\b20\d{2}\s*/\s*\d{2,3}\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Type-approval extension numbers (`*0085*`, `00861`) must not be read as kg.
    private static func looksLikeTypeApprovalMassFragment(raw: String, line: String) -> Bool {
        let digits = raw.replacingOccurrences(of: "[.,]", with: "", options: .regularExpression)
        if digits.hasPrefix("0"), digits.count >= 3 { return true }
        if looksLikeTypeApprovalLine(line), (Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0) < 1000 {
            return true
        }
        let escaped = NSRegularExpression.escapedPattern(for: digits)
        if line.range(of: "\\*\\s*0*\(escaped)\\s*\\*", options: .regularExpression) != nil { return true }
        if line.range(of: "\\b20\\d{2}\\s*/\\s*\\d{2,3}\\b", options: .regularExpression) != nil,
           (2000...2035).contains(Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0) {
            return true
        }
        return false
    }

    private static func looksLikeEUStatutoryPlate(_ lines: [String]) -> Bool {
        if lines.contains(where: looksLikeTypeApprovalLine) { return true }
        return lines.contains { line in
            line.contains("ETAPE") || line.contains("STUFE") || line.contains("STAGE")
                || line.contains("FASE") || line.contains("STADIUM")
        }
    }

    /// EU 19/2011 / 2021/535: motorhomes are MAM, GTW, then `1-` / `2-` / `3-`.
    /// Trailers (O1/O2 caravans) omit GTW and number the coupling point as `0-`.
    private static func applyEUStatutoryMasses(
        in lines: [String],
        to suggestions: inout VehiclePlateSuggestions,
        claimedValues: inout Set<Double>,
        notes: inout [String]
    ) {
        let hyphenAxleLines = lines.contains { prefixedAxleNumber(in: $0) != nil }
        let isTrailerStatutoryLayout = lines.contains { prefixedAxleNumber(in: $0) == 0 }

        if let coupling = prefixedAxleMass(in: lines, axleNumber: 0, excluding: claimedValues, range: noseRange),
           suggestions.hitchOrNoseKg == nil {
            suggestions.hitchOrNoseKg = coupling
            claimedValues.insert(coupling)
            notes.append("Hitch / nose / coupling load recognised from the EU trailer plate layout (axle 0).")
        }

        // Twin-axle caravans often share the same plated maximum; do not treat that as a duplicate claim.
        let axleExcluding = claimedValues.subtracting(
            [suggestions.maxFrontAxleKg, suggestions.maxRearAxleKg].compactMap { $0 }
        )
        if let front = prefixedAxleMass(in: lines, axleNumber: 1, excluding: axleExcluding),
           suggestions.maxFrontAxleKg == nil {
            suggestions.maxFrontAxleKg = front
            claimedValues.insert(front)
            notes.append("Front axle limit recognised from the EU statutory plate layout (axle 1).")
        }
        if let rear = prefixedAxleMass(in: lines, axleNumber: 2, excluding: axleExcluding),
           suggestions.maxRearAxleKg == nil {
            suggestions.maxRearAxleKg = rear
            claimedValues.insert(rear)
            notes.append("Rear axle limit recognised from the EU statutory plate layout (axle 2).")
        }

        let unlabeled = statutoryMassSequence(unlabeledMassValues(in: lines, excluding: claimedValues))

        if hyphenAxleLines {
            assignStatutoryMassesFromUnlabeled(
                unlabeled.sorted(),
                to: &suggestions,
                claimedValues: &claimedValues,
                notes: &notes,
                positionalAxles: false,
                omitCombinationMass: isTrailerStatutoryLayout
            )
            return
        }

        guard looksLikeEUStatutoryPlate(lines) || looksLikeKnownMultiStageConverter(lines) else { return }
        assignStatutoryMassesFromUnlabeled(
            unlabeled,
            to: &suggestions,
            claimedValues: &claimedValues,
            notes: &notes,
            positionalAxles: true,
            omitCombinationMass: isTrailerStatutoryLayout
        )
    }

    /// Drop type-approval leftovers (e.g. 85 from `*0085*`) that would shift MAM/GTW/axle order.
    private static func statutoryMassSequence(_ unlabeled: [Double]) -> [Double] {
        var values = unlabeled.filter { vehicleMassRange.contains($0) }
        while values.count >= 2, values[0] < 1_000, values[1] >= 1_500, values[1] >= values[0] * 4 {
            values.removeFirst()
        }
        return values
    }

    private static func looksLikeKnownMultiStageConverter(_ lines: [String]) -> Bool {
        let tokens = [
            "RAPIDO", "PILOTE", "G P SAS", "GP SAS", "HYMER", "BURSTNER", "BUERSTNER",
            "DETHLEFFS", "CHAUSSON", "ITINEO", "CARTHAGO", "NIESMANN", "FRANKIA", "KNAUS"
        ]
        return lines.contains { line in tokens.contains(where: { line.contains($0) }) }
    }

    private static func assignStatutoryMassesFromUnlabeled(
        _ unlabeled: [Double],
        to suggestions: inout VehiclePlateSuggestions,
        claimedValues: inout Set<Double>,
        notes: inout [String],
        positionalAxles: Bool,
        omitCombinationMass: Bool
    ) {
        guard !unlabeled.isEmpty else { return }

        if positionalAxles {
            if suggestions.mtplmOrMamKg == nil, unlabeled.count >= 1 {
                suggestions.mtplmOrMamKg = unlabeled[0]
                claimedValues.insert(unlabeled[0])
                notes.append("Maximum laden mass recognised from the EU statutory plate order.")
            }
            if !omitCombinationMass,
               suggestions.gtwKg == nil,
               unlabeled.count >= 2,
               unlabeled[1] > (suggestions.mtplmOrMamKg ?? unlabeled[0]) {
                suggestions.gtwKg = unlabeled[1]
                claimedValues.insert(unlabeled[1])
                notes.append("Gross train weight recognised from the EU statutory plate order.")
            }
            let axleStart = omitCombinationMass ? 1 : 2
            if suggestions.maxFrontAxleKg == nil, unlabeled.count >= axleStart + 1 {
                suggestions.maxFrontAxleKg = unlabeled[axleStart]
                claimedValues.insert(unlabeled[axleStart])
                notes.append("Front axle limit recognised from the EU statutory plate order.")
            }
            if suggestions.maxRearAxleKg == nil, unlabeled.count >= axleStart + 2 {
                suggestions.maxRearAxleKg = unlabeled[axleStart + 1]
                claimedValues.insert(unlabeled[axleStart + 1])
                notes.append("Rear axle limit recognised from the EU statutory plate order.")
            }
            return
        }

        // Hyphenated axles already identified: remaining values are MAM then GTW (MAM < GTW).
        // Trailers omit combination mass under EU 19/2011 / 2021/535.
        if suggestions.mtplmOrMamKg == nil, unlabeled.count >= 1 {
            suggestions.mtplmOrMamKg = unlabeled[0]
            claimedValues.insert(unlabeled[0])
            notes.append("Maximum laden mass recognised from the EU statutory plate layout.")
        }
        if !omitCombinationMass,
           unlabeled.count >= 2,
           suggestions.gtwKg == nil,
           unlabeled[1] > (suggestions.mtplmOrMamKg ?? unlabeled[0]) {
            suggestions.gtwKg = unlabeled[1]
            claimedValues.insert(unlabeled[1])
            notes.append("Gross train weight recognised from the EU statutory plate layout.")
        }
    }

    private static func prefixedAxleNumber(in line: String) -> Int? {
        prefixedAxleMatch(in: line)?.number
    }

    private static func prefixedAxleMass(
        in lines: [String],
        axleNumber: Int,
        excluding: Set<Double>,
        range: ClosedRange<Double> = vehicleMassRange
    ) -> Double? {
        for line in lines {
            guard let match = prefixedAxleMatch(in: line), match.number == axleNumber else { continue }
            guard let mass = match.mass, range.contains(mass), !excluding.contains(mass) else { continue }
            return mass
        }
        return nil
    }

    private static func prefixedAxleMatch(in line: String) -> (number: Int, mass: Double?)? {
        // Embossed plates often OCR `1-` as `I-` / `L-` / `|-`.
        let adjusted = line.replacingOccurrences(
            of: #"\b[IL|]\s*[-–—.\:\)]"#,
            with: "1-",
            options: .regularExpression
        )
        guard let regex = try? NSRegularExpression(pattern: #"\b([0123])\s*[-–—.\:\)]\s*(\d{3,5})?\b"#) else {
            return nil
        }
        let range = NSRange(adjusted.startIndex..<adjusted.endIndex, in: adjusted)
        guard let match = regex.firstMatch(in: adjusted, range: range),
              match.numberOfRanges >= 2,
              let numberRange = Range(match.range(at: 1), in: adjusted),
              let number = Int(adjusted[numberRange]) else {
            return nil
        }
        var mass: Double?
        if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
           let massRange = Range(match.range(at: 2), in: adjusted),
           let value = Double(adjusted[massRange]) {
            mass = value.rounded()
        }
        return (number, mass)
    }

    private static func unlabeledMassValues(in lines: [String], excluding: Set<Double>) -> [Double] {
        var values: [Double] = []
        var claimed = excluding
        let statutoryContext = looksLikeEUStatutoryPlate(lines) || looksLikeKnownMultiStageConverter(lines)
        for line in lines {
            guard !shouldSkipUnlabeledMassLine(line) else { continue }
            let axleMasses = Set((0...3).compactMap { prefixedAxleMass(in: [line], axleNumber: $0, excluding: []) })
            for value in massValuesExcludingProtectedSpans(in: line) {
                guard vehicleMassRange.contains(value), !claimed.contains(value), !axleMasses.contains(value) else { continue }
                if isMostlyMassLine(line, value: value)
                    || statutoryContext
                    || prefixedAxleNumber(in: line) != nil {
                    values.append(value)
                    claimed.insert(value)
                }
            }
        }
        return values
    }

    private static func massValuesExcludingProtectedSpans(in line: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{2,5}(?:[.,]\d{1,2})?)\b"#) else {
            return []
        }
        let protected = protectedNonMassRanges(in: line)
        let searchRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: searchRange).compactMap { match in
            guard let matchRange = Range(match.range(at: 1), in: line) else { return nil }
            if protected.contains(where: { $0.overlaps(matchRange) }) { return nil }
            let raw = String(line[matchRange]).replacingOccurrences(of: ",", with: ".")
            if looksLikeTypeApprovalMassFragment(raw: raw, line: line) { return nil }
            guard let value = Double(raw) else { return nil }
            return value.rounded()
        }
    }

    private static func protectedNonMassRanges(in line: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let patterns = [
            #"[EGN]\d{1,2}\s*\*?\s*\d{2,4}\s*/\s*\d{2,3}(?:\s*\*\s*\d+)*"#,
            #"\*\s*0*\d{2,4}\s*\*"#,
            #"\b20\d{2}\s*/\s*\d{2,3}\b"#,
            #"[A-HJ-NPR-Z][A-Z0-9IOQ]{16}"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let searchRange = NSRange(line.startIndex..<line.endIndex, in: line)
            for match in regex.matches(in: line, range: searchRange) {
                if let range = Range(match.range, in: line) {
                    ranges.append(range)
                }
            }
        }
        return ranges
    }

    private static func shouldSkipUnlabeledMassLine(_ line: String) -> Bool {
        if looksLikeTypeApprovalLine(line), !line.contains("KG"), prefixedAxleNumber(in: line) == nil {
            return true
        }
        let habitationTokens = [
            "CELLULE", "BODY NUMBER", "BODY NO", "CONVERSION",
            "AUFBAU", "KAROSSERIE", "WOHNKABINE"
        ]
        if habitationTokens.contains(where: { line.contains($0) }) { return true }
        if VehicleVINParsing.isPlausibleVIN(line.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)),
           !looksLikeTypeApprovalLine(line),
           prefixedAxleNumber(in: line) == nil,
           !line.contains("KG") {
            return true
        }
        if VehicleVINParsing.looksLikePowerOrEngineNoise(line),
           prefixedAxleNumber(in: line) == nil,
           !line.contains("KG") {
            return true
        }
        let identityTokens = [
            "YEAR", "DATE", "ENGINE", "POWER", "KW", "RPM", "MAKE", "MODEL",
            "MANUFACTURER", "HERSTELLER", "MARQUE", "FABRICANT", "FABRICANTE",
            "FABRIKANT", "COSTRUTTORE", "AXLES", "MAXIMUM WEIGHTS"
        ]
        if identityTokens.contains(where: { line.contains($0) }),
           prefixedAxleNumber(in: line) == nil,
           !line.contains("KG") {
            return true
        }
        if mtplmLabels.contains(where: { line.contains($0) }) { return true }
        if gtwLabels.contains(where: { line.contains($0) }) { return true }
        if miroLabels.contains(where: { line.contains($0) }) { return true }
        if noseLabels.contains(where: { line.contains($0) }) { return true }
        if frontAxleLabels.contains(where: { line.contains($0) }) { return true }
        if rearAxleLabels.contains(where: { line.contains($0) }) { return true }
        return false
    }

    private static func isMostlyMassLine(_ line: String, value: Double) -> Bool {
        let valueText = String(format: "%.0f", value)
        let remainder = line
            .replacingOccurrences(of: valueText, with: "")
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
        return remainder.isEmpty
    }

    // MARK: - Tyre pressure & wheel torque

    private enum WheelMaterialPreference {
        case steel
        case alloy
    }

    private static let pressureLabels: [String] = [
        "COLD INFLATION PRESSURE",
        "INFLATION PRESSURE",
        "TYRE PRESSURE",
        "TIRE PRESSURE",
        "RECOMMENDED PRESSURE",
        "PRESSURE"
    ]

    private static let torqueLabels: [String] = [
        "WHEEL NUT TORQUE",
        "WHEEL BOLT TORQUE",
        "WHEEL NUTS",
        "WHEEL BOLTS",
        "NUT TORQUE",
        "BOLT TORQUE",
        "TORQUE"
    ]

    private static func firstTyrePressure(in lines: [String]) -> (psi: Double, displayUnit: PressureUnit)? {
        // Prefer explicitly unit-labelled values anywhere on the plate.
        if let match = firstPressureWithUnit(in: lines) {
            return match
        }

        let sortedLabels = pressureLabels.sorted { $0.count > $1.count }
        for (index, line) in lines.enumerated() {
            guard sortedLabels.contains(where: { line.contains($0) }) else { continue }
            let candidates = [line] + (index + 1 < lines.count ? [lines[index + 1]] : [])
            if let match = firstPressureWithUnit(in: candidates) {
                return match
            }
            // Bare number next to a pressure label — assume bar when < 10, else PSI.
            for candidate in candidates {
                guard let value = firstDecimal(in: candidate) else { continue }
                if (1.5...8.0).contains(value) {
                    let psi = TyreSupport.convertPressure(value, from: .bar, to: .psi)
                    return (psi.rounded(), .bar)
                }
                if (25...120).contains(value) {
                    return (value.rounded(), .psi)
                }
            }
        }
        return nil
    }

    private static func firstPressureWithUnit(in lines: [String]) -> (psi: Double, displayUnit: PressureUnit)? {
        let patterns: [(String, PressureUnit)] = [
            (#"(\d{1,3}(?:[.,]\d{1,2})?)\s*BAR\b"#, .bar),
            (#"(\d{1,3}(?:[.,]\d{1,2})?)\s*PSI\b"#, .psi),
            (#"(\d{2,4}(?:[.,]\d{1,2})?)\s*KPA\b"#, .bar) // convert via kPa → bar below
        ]

        for line in lines {
            for (pattern, unit) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      match.numberOfRanges >= 2,
                      let valueRange = Range(match.range(at: 1), in: line) else { continue }
                let raw = String(line[valueRange]).replacingOccurrences(of: ",", with: ".")
                guard let value = Double(raw) else { continue }

                if pattern.contains("KPA") {
                    let bar = value / 100.0
                    guard (1.5...8.0).contains(bar) else { continue }
                    let psi = TyreSupport.convertPressure(bar, from: .bar, to: .psi)
                    return (psi.rounded(), .bar)
                }

                switch unit {
                case .bar:
                    guard (1.5...8.0).contains(value) else { continue }
                    let psi = TyreSupport.convertPressure(value, from: .bar, to: .psi)
                    return (psi.rounded(), .bar)
                case .psi:
                    guard (25...120).contains(value) else { continue }
                    return (value.rounded(), .psi)
                }
            }
        }
        return nil
    }

    private static func firstWheelNutTorque(in lines: [String], preference: WheelMaterialPreference) -> Double? {
        let materialTokens: [String]
        switch preference {
        case .steel:
            materialTokens = ["STEEL", "STEEL WHEEL", "STEEL RIM"]
        case .alloy:
            materialTokens = ["ALLOY", "ALUMINIUM", "ALUMINUM", "ALLOY WHEEL"]
        }

        // "STEEL 110 NM" / "ALLOY 130 NM"
        for line in lines {
            for token in materialTokens.sorted(by: { $0.count > $1.count }) where line.contains(token) {
                if let nm = torqueValue(near: token, in: line) ?? torqueValueOnFollowingLines(after: line, in: lines) {
                    return nm
                }
            }
        }

        // Only fall back to generic torque for steel — plates often list one value meant for steel wheels.
        guard preference == .steel else { return nil }

        let sortedLabels = torqueLabels.sorted { $0.count > $1.count }
        for (index, line) in lines.enumerated() {
            guard let label = sortedLabels.first(where: { line.contains($0) }) else { continue }
            // Skip lines that clearly refer only to alloy.
            if line.contains("ALLOY") || line.contains("ALUMINIUM") || line.contains("ALUMINUM") {
                continue
            }
            if let nm = torqueValue(near: label, in: line) {
                return nm
            }
            if index + 1 < lines.count, let nm = firstTorqueNm(in: lines[index + 1]) {
                return nm
            }
        }
        return nil
    }

    private static func torqueValue(near token: String, in line: String) -> Double? {
        guard let tokenRange = line.range(of: token) else { return nil }
        let after = String(line[tokenRange.upperBound...])
        if let nm = firstTorqueNm(in: after) { return nm }
        let before = String(line[..<tokenRange.lowerBound])
        return firstTorqueNm(in: before)
    }

    private static func torqueValueOnFollowingLines(after line: String, in lines: [String]) -> Double? {
        guard let index = lines.firstIndex(of: line), index + 1 < lines.count else { return nil }
        return firstTorqueNm(in: lines[index + 1])
    }

    private static func firstTorqueNm(in text: String) -> Double? {
        let patterns = [
            #"(\d{2,3}(?:[.,]\d{1,2})?)\s*NM\b"#,
            #"(\d{2,3}(?:[.,]\d{1,2})?)\s*N\.?M\b"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges >= 2,
                  let valueRange = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[valueRange]).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(raw) else { continue }
            let rounded = value.rounded()
            guard (60...220).contains(rounded) else { continue }
            return rounded
        }
        return nil
    }

    private static func firstDecimal(in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,3}(?:[.,]\d{1,2})?)\b"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range(at: 1), in: text) else { return nil }
        let raw = String(text[matchRange]).replacingOccurrences(of: ",", with: ".")
        return Double(raw)
    }

    // MARK: - Manufacturer & model

    /// Canonical brand plus match tokens (longest first preferred at call site).
    private static let knownManufacturers: [(canonical: String, tokens: [String])] = [
        ("Swift", ["SWIFT GROUP LIMITED", "SWIFT GROUP LTD", "SWIFT GROUP", "SWIFT"]),
        ("Bailey", ["BAILEY OF BRISTOL", "BAILEY CARAVANS", "BAILEY"]),
        ("Coachman", ["COACHMAN CARAVAN", "COACHMAN"]),
        ("Elddis", ["ELDDIS"]),
        ("Compass", ["COMPASS"]),
        ("Buccaneer", ["BUCCANEER"]),
        ("Xplore", ["XPLORE"]),
        ("Adria", ["ADRIA"]),
        ("Auto-Trail", ["AUTO-TRAIL", "AUTO TRAIL", "AUTOTRAIL"]),
        ("Chausson", ["CHAUSSON"]),
        ("Burstner", ["BURSTNER", "BUERSTNER", "BÜRSTNER"]),
        ("Hobby", ["HOBBY"]),
        ("Lunar", ["LUNAR"]),
        ("Sprite", ["SPRITE"]),
        ("Sterling", ["STERLING"]),
        ("Bessacarr", ["BESSACARR"]),
        ("Vanmaster", ["VANMASTER"]),
        ("Knaus", ["KNAUS"]),
        ("Hymer", ["HYMER"]),
        ("Dethleffs", ["DETHLEFFS"]),
        ("Frankia", ["FRANKIA"]),
        ("Pilote", ["GROUPE PILOTE", "G P SAS", "GP SAS", "GPSAS", "PILOTE"]),
        ("Rapido", ["RAPIDO"]),
        ("Carthago", ["CARTHAGO"]),
        ("Niesmann", ["NIESMANN", "NIESMANN+BISCHOFF", "NIESMANN BISCHOFF"]),
        ("Mobilvetta", ["MOBILVETTA"]),
        ("Roller Team", ["ROLLER TEAM", "ROLLERTEAM"]),
        ("Itineo", ["ITINEO"]),
        ("Benimar", ["BENIMAR"]),
        ("Rimor", ["RIMOR"]),
        ("WildAx", ["WILDAX"]),
        ("Devon", ["DEVON"]),
        ("Hillside", ["HILLSIDE"]),
        ("Murvi", ["MURVI"]),
        ("Fendt", ["FENDT"]),
        ("Tabbert", ["TABBERT"]),
        ("LMC", ["LMC"]),
        ("Eriba", ["ERIBA"]),
        ("Weinsberg", ["WEINSBERG"]),
        ("Sterckeman", ["STERCKEMAN"]),
        ("Caravelair", ["CARAVELAIR"]),
        ("Trigano", ["TRIGANO"]),
        ("Auto-Sleeper", ["AUTO-SLEEPER", "AUTO SLEEPER", "AUTOSLEEPER"]),
        ("Globecar", ["GLOBECAR"]),
        ("Westfalia", ["WESTFALIA"]),
        ("Morelo", ["MORELO"]),
        ("Laika", ["LAIKA"]),
        ("McLouis", ["MCLOUIS", "MC LOUIS"]),
        ("Iveco", ["IVECO"]),
        ("Peugeot", ["PEUGEOT"]),
        ("Citroën", ["CITROEN", "CITROËN"]),
        ("Renault", ["RENAULT"]),
        ("VW", ["VOLKSWAGEN", "VW"]),
        ("Fiat", ["FIAT"]),
        ("Ford", ["FORD"]),
        ("Mercedes-Benz", ["MERCEDES-BENZ", "MERCEDES BENZ", "MERCEDES"])
    ]

    private static let manufacturerLabels: [String] = [
        "MANUFACTURER",
        "HERSTELLER",
        "COSTRUTTORE",
        "FABBRICANTE",
        "FABRICANTE",
        "FABRIKANT",
        "MAKE",
        "MAKER",
        "FABRICANT",
        "MARQUE"
    ]

    private static let modelLabels: [String] = [
        "MODEL NAME",
        "MODEL TYPE",
        "TYPE DESIGNATION",
        "TYPBEZEICHNUNG",
        "DESIGNATION COMMERCIALE",
        "COMMERCIAL NAME",
        "MODEL",
        "TYPE",
        "TIPO",
        "TYP",
        "VARIANT"
    ]

    private static let modelNoiseTokens: Set<String> = [
        "LIMITED", "LTD", "GROUP", "PLC", "COMPANY", "CO", "CARAVANS", "CARAVAN",
        "MOTORHOMES", "MOTORHOME", "OF", "THE", "AND", "UK", "NCC", "VIN",
        "CHASSIS", "CRIS", "MTPLM", "MIRO", "MAM", "MMA", "MRO", "MTO", "GTW", "GTM",
        "GVM", "PTRA", "KG", "BAR", "PSI", "STEEL", "ALLOY", "TYRE", "TIRE", "PRESSURE",
        "TORQUE", "WHEEL", "NUT", "CELLULE", "ETAPE", "STUFE", "STAGE", "FASE",
        "STADIUM", "FIN", "TELAIO", "BASTIDOR", "STUTZLAST", "LEERMASSE", "LEERGEWICHT"
    ]

    private static func firstManufacturer(in lines: [String], vin: String?) -> String? {
        // Prefer an explicit MAKE/MANUFACTURER label.
        let sortedLabels = manufacturerLabels.sorted { $0.count > $1.count }
        for (index, line) in lines.enumerated() {
            guard let label = sortedLabels.first(where: { line.contains($0) }) else { continue }
            let after = valueAfterLabel(label, in: line)
            let candidates = [after, index + 1 < lines.count ? lines[index + 1] : nil].compactMap { $0 }
            for candidate in candidates {
                if let match = matchKnownManufacturer(in: candidate) {
                    return match
                }
            }
        }

        // Scan all lines for known brand tokens (longest token wins).
        var best: (canonical: String, tokenLength: Int)?
        for line in lines {
            for maker in knownManufacturers {
                for token in maker.tokens {
                    guard line.contains(token) else { continue }
                    if best == nil || token.count > best!.tokenLength {
                        best = (maker.canonical, token.count)
                    }
                }
            }
        }
        if let best { return best.canonical }

        if let vin, let fromVIN = manufacturerFromVIN(vin) {
            return fromVIN
        }

        return nil
    }

    private static func matchKnownManufacturer(in text: String) -> String? {
        let upper = text.uppercased()
        var best: (canonical: String, tokenLength: Int)?
        for maker in knownManufacturers {
            for token in maker.tokens {
                guard upper.contains(token) else { continue }
                if best == nil || token.count > best!.tokenLength {
                    best = (maker.canonical, token.count)
                }
            }
        }
        return best?.canonical
    }

    /// ISO 3780 WMI first, then UK CRiS codes on SG-style VINs, then base-chassis WMI.
    private static func manufacturerFromVIN(_ vin: String) -> String? {
        let upper = vin.uppercased()
        guard upper.count >= 3 else { return nil }

        let wmi = String(upper.prefix(3))
        if let maker = manufacturerFromLeisureWMI(wmi) {
            return maker
        }

        if looksLikeCRiSVIN(upper), upper.count >= 9 {
            let code = String(upper.prefix(9).suffix(2))
            if let fromCRiS = manufacturerFromCRiSCode(code) {
                return fromCRiS
            }
        }

        return manufacturerFromChassisWMI(wmi)
    }

    private static func looksLikeCRiSVIN(_ vin: String) -> Bool {
        vin.hasPrefix("SG")
            || vin.hasPrefix("SA9")
            || vin.hasPrefix("VFM")
            || vin.hasPrefix("VGZ")
    }

    private static func manufacturerFromLeisureWMI(_ wmi: String) -> String? {
        switch wmi {
        case "ZY1", "VY1": return "Adria"
        case "WHB": return "Hobby"
        case "WXF", "WFC": return "Fendt"
        case "WO9": return "LMC"
        case "WTA": return "Tabbert"
        case "ZB5": return "Rimor"
        default: return nil
        }
    }

    private static func manufacturerFromChassisWMI(_ wmi: String) -> String? {
        switch wmi {
        case "ZFA": return "Fiat"
        case "VF3": return "Peugeot"
        case "VF7": return "Citroën"
        case "VF1": return "Renault"
        case "ZCF": return "Iveco"
        case "WF0", "VS6", "SFA": return "Ford"
        case "WDB", "W1V", "WDF": return "Mercedes-Benz"
        case "WV1", "WV2", "WV3": return "VW"
        default: return nil
        }
    }

    private static func manufacturerFromCRiSCode(_ code: String) -> String? {
        switch code {
        case "SW": return "Swift"
        case "BY": return "Bailey"
        case "CM": return "Coachman"
        case "EL", "EX": return "Elddis"
        case "AD": return "Adria"
        case "LU": return "Lunar"
        case "CU": return "Sprite"
        case "BE": return "Bessacarr"
        case "BU": return "Buccaneer"
        case "CP": return "Compass"
        case "VM": return "Vanmaster"
        case "HY": return "Hobby"
        case "AV": return "Avondale"
        case "AB": return "ABI"
        case "CL": return "Carlight"
        case "CS": return "Cosalt"
        case "FL": return "Fleetwood"
        case "CE": return "Chateau"
        case "CK": return "Sterckeman"
        case "TB": return "Tabbert"
        case "LM": return "LMC"
        case "RI": return "Rimor"
        case "GR": return "Gobur"
        case "MA": return "Mardon"
        default: return nil
        }
    }

    private static func firstModelName(in lines: [String], manufacturer: String) -> String? {
        if let labeled = firstLabeledModelName(in: lines) {
            return labeled
        }

        let manufacturerUpper = manufacturer.uppercased()
        let makerTokens = knownManufacturers
            .first(where: { $0.canonical.caseInsensitiveCompare(manufacturer) == .orderedSame })?
            .tokens ?? [manufacturerUpper]

        for (index, line) in lines.enumerated() {
            guard makerTokens.contains(where: { line.contains($0) }) else { continue }

            var remainder = line
            for token in makerTokens.sorted(by: { $0.count > $1.count }) {
                remainder = remainder.replacingOccurrences(of: token, with: " ")
            }
            if let model = cleanedModelCandidate(remainder), isPlausibleModel(model) {
                return model
            }

            if index + 1 < lines.count,
               let model = cleanedModelCandidate(lines[index + 1]),
               isPlausibleModel(model) {
                return model
            }
        }

        // Standalone model-like line elsewhere on the plate (e.g. CONQUEROR 645).
        for line in lines {
            if makerTokens.contains(where: { line.contains($0) }) { continue }
            if manufacturerLabels.contains(where: { line.contains($0) }) { continue }
            if modelLabels.contains(where: { line.contains($0) }) { continue }
            if let model = cleanedModelCandidate(line), isPlausibleModel(model), looksLikeModelRange(model) {
                return model
            }
        }

        return nil
    }

    private static func firstLabeledModelName(in lines: [String]) -> String? {
        let sortedLabels = modelLabels.sorted { $0.count > $1.count }
        for (index, line) in lines.enumerated() {
            guard let label = sortedLabels.first(where: { line.contains($0) }) else { continue }
            let after = valueAfterLabel(label, in: line)
            if let after, let model = cleanedModelCandidate(after), isPlausibleModel(model) {
                return model
            }
            if index + 1 < lines.count,
               let model = cleanedModelCandidate(lines[index + 1]),
               isPlausibleModel(model) {
                return model
            }
        }
        return nil
    }

    private static func valueAfterLabel(_ label: String, in line: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        let after = String(line[range.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: " :#-"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return after.isEmpty ? nil : after
    }

    private static func cleanedModelCandidate(_ raw: String) -> String? {
        var text = raw.uppercased()
        // Strip known maker tokens and corporate noise.
        for maker in knownManufacturers {
            for token in maker.tokens {
                text = text.replacingOccurrences(of: token, with: " ")
            }
        }
        for label in manufacturerLabels + modelLabels {
            text = text.replacingOccurrences(of: label, with: " ")
        }

        text = text
            .replacingOccurrences(of: #"[^A-Z0-9\-/ ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = text.split(separator: " ").map(String.init).filter { token in
            guard token.count > 1 else { return false }
            if modelNoiseTokens.contains(token) { return false }
            if mtplmLabels.contains(token) || miroLabels.contains(token) { return false }
            if token.range(of: #"^\d{3}/\d{2}"#, options: .regularExpression) != nil { return false }
            if token.range(of: #"^\d{3}R\d{2}"#, options: .regularExpression) != nil { return false }
            return true
        }

        guard !tokens.isEmpty else { return nil }
        let candidate = tokens.prefix(5).joined(separator: " ")
        guard candidate.count >= 3 else { return nil }
        return candidate.capitalized
    }

    private static func isPlausibleModel(_ value: String) -> Bool {
        let upper = value.uppercased()
        if upper.count < 3 || upper.count > 40 { return false }
        if knownManufacturers.contains(where: { $0.canonical.caseInsensitiveCompare(value) == .orderedSame }) {
            return false
        }
        // Reject pure numbers / masses.
        if upper.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil { return false }
        if VehicleVINParsing.isPlausibleVIN(upper.replacingOccurrences(of: " ", with: "")) { return false }
        if looksLikeTypeApprovalLine(upper) || looksLikeTypeApprovalToken(upper.replacingOccurrences(of: " ", with: "")) {
            return false
        }
        return true
    }

    private static func looksLikeModelRange(_ value: String) -> Bool {
        let upper = value.uppercased()
        // Common range + number patterns: CONQUEROR 645, UNICORN CADIZ, ALCANTARA 640
        if upper.range(of: #"^[A-Z][A-Z0-9\-]+(?:\s+[A-Z0-9\-]+){0,3}\s+\d{2,4}[A-Z]?$"#, options: .regularExpression) != nil {
            return true
        }
        if upper.range(of: #"^[A-Z][A-Z\-]+(?:\s+[A-Z][A-Z\-]+){1,3}$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}
