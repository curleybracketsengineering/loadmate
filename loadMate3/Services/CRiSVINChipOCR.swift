import Foundation
import UIKit
import Vision

struct CRiSVINChipSuggestions: Identifiable {
    enum Source: String {
        case qrCode
        case ocrText
    }

    let id = UUID()
    var vinChassisNumber: String?
    var source: Source?
    var confidenceNotes: [String] = []

    var hasAnySuggestion: Bool {
        vinChassisNumber != nil
    }
}

/// Reads a CRiS / VIN Chip sticker: QR payload first, then printed VIN via OCR.
enum CRiSVINChipOCR {
    static func analyze(image: UIImage) async throws -> CRiSVINChipSuggestions {
        // QR detection can fail on some photos; still attempt printed-VIN OCR.
        async let payloads = recognizeQRPayloadsIgnoringErrors(in: image)
        async let lines = VehiclePlateOCR.recognizeLines(in: image)
        return suggestions(fromQRPayloads: await payloads, ocrLines: try await lines)
    }

    static func suggestions(fromQRPayloads payloads: [String], ocrLines: [String]) -> CRiSVINChipSuggestions {
        var notes: [String] = []

        for payload in payloads {
            if let vin = vinFromQRPayload(payload) {
                notes.append("VIN recognised from the CRiS VIN Chip QR code.")
                return CRiSVINChipSuggestions(
                    vinChassisNumber: vin,
                    source: .qrCode,
                    confidenceNotes: notes
                )
            }
        }

        if !payloads.isEmpty {
            notes.append("A QR code was found, but no VIN could be read from it. Checking printed text…")
        }

        let plate = VehiclePlateOCR.suggestions(from: ocrLines)
        if let vin = plate.vinChassisNumber {
            notes.append("VIN recognised from printed text on the VIN Chip sticker or lozenge.")
            return CRiSVINChipSuggestions(
                vinChassisNumber: vin,
                source: .ocrText,
                confidenceNotes: notes
            )
        }

        notes.append("No VIN could be recognised from the QR code or printed text. Try a closer, sharper photo of the VIN Chip sticker.")
        return CRiSVINChipSuggestions(confidenceNotes: notes)
    }

    /// Extracts a VIN from a QR payload (raw VIN, URL query/path, or embedded text).
    static func vinFromQRPayload(_ payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let vin = VehicleVINParsing.firstVIN(in: [trimmed]) {
            return vin
        }

        let sanitizedWhole = VehicleVINParsing.canonicalize(trimmed)
        if VehicleVINParsing.isPlausibleVIN(sanitizedWhole) {
            return sanitizedWhole
        }

        if let url = URL(string: trimmed) {
            if let fromQuery = vinFromURLQuery(url) {
                return fromQuery
            }
            if let fromPath = vinFromURLPath(url) {
                return fromPath
            }
        }

        // Some stickers encode query-style text without a full URL scheme.
        if let fromLooseQuery = vinFromLooseQuery(trimmed) {
            return fromLooseQuery
        }

        return nil
    }

    // MARK: - Vision

    private static func recognizeQRPayloadsIgnoringErrors(in image: UIImage) async -> [String] {
        (try? await recognizeQRPayloads(in: image)) ?? []
    }

    private static func recognizeQRPayloads(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            // Vision may invoke the request callback and also throw from `perform`.
            var didResume = false
            func resumeOnce(_ body: (CheckedContinuation<[String], Error>) -> Void) {
                guard !didResume else { return }
                didResume = true
                body(continuation)
            }

            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    resumeOnce { $0.resume(throwing: error) }
                    return
                }
                let observations = request.results as? [VNBarcodeObservation] ?? []
                let payloads = observations.compactMap { observation -> String? in
                    guard observation.symbology == .qr,
                          let payload = observation.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !payload.isEmpty else { return nil }
                    return payload
                }
                resumeOnce { $0.resume(returning: payloads) }
            }
            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce { $0.resume(throwing: error) }
            }
        }
    }

    // MARK: - Parsing

    private static func vinFromURLQuery(_ url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let keys = ["vin", "VIN", "chassis", "cris", "id", "serial"]
        for item in components.queryItems ?? [] {
            guard keys.contains(where: { $0.caseInsensitiveCompare(item.name) == .orderedSame }),
                  let value = item.value else { continue }
            let candidate = VehicleVINParsing.canonicalize(value)
            if VehicleVINParsing.isPlausibleVIN(candidate) { return candidate }
        }
        return nil
    }

    private static func vinFromURLPath(_ url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        for part in parts.reversed() {
            let candidate = VehicleVINParsing.canonicalize(part)
            if VehicleVINParsing.isPlausibleVIN(candidate) { return candidate }
        }
        return nil
    }

    private static func vinFromLooseQuery(_ text: String) -> String? {
        let keys = ["vin", "chassis", "cris", "id", "serial"]
        for key in keys {
            let pattern = #"\#(key)\s*[=:]\s*([A-Za-z0-9]{8,17})"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges >= 2,
                  let valueRange = Range(match.range(at: 1), in: text) else { continue }
            let candidate = VehicleVINParsing.canonicalize(String(text[valueRange]))
            if VehicleVINParsing.isPlausibleVIN(candidate) { return candidate }
        }
        return nil
    }

}
