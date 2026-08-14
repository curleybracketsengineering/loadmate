import Foundation

struct AccidentGuidanceInput: Equatable, Sendable {
    var jurisdiction: AccidentJurisdiction = .unitedKingdom
    var anyoneInjured: Bool = false
    var sceneUnsafeOrBlocked: Bool = false
    var suspectedImpairmentOrViolence: Bool = false
    var hitAndRun: Bool = false
    var detailsExchanged: Bool = false
    var insuranceCertificateSeen: Bool = false
    var otherDriverRefused: Bool = false
    var vehicleKind: VehicleKind = .caravan
    var hasTowOrTrailer: Bool = false
    var redFlags: Set<AccidentRedFlag> = []
    var otherVehicleIsForeign: Bool = false
}

struct AccidentGuidanceCard: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case disclaimer
        case emergency
        case police
        case insurer
        case exchange
        case photos
        case eas
        case lookup
        case note
        case safety
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String
    var callNumber: String?
    var linkURL: URL?
    var linkTitle: String?
}

struct AccidentGuidanceResult: Equatable, Sendable {
    var emergencyNumber: String
    var shouldCallEmergencyNow: Bool
    var shouldReportPolice: Bool
    var policeNumber: String?
    var shouldNotifyInsurer: Bool
    var processBranch: AccidentProcessBranch
    var cards: [AccidentGuidanceCard]
    var photoKinds: [AccidentPhotoKind]
}

enum AccidentLinks {
    static let govUKAccident = URL(string: "https://www.gov.uk/vehicle-insurance/if-youre-in-an-accident")!
    static let govUKNoMOT = URL(string: "https://www.gov.uk/report-no-mot")!
    static let metPoliceCollisions = URL(string: "https://www.met.police.uk/advice/advice-and-information/rs/road-safety/collisions/")!
    static let mibForeignInUK = URL(string: "https://www.mib.org.uk/make-a-claim/ive-been-hit-by-a-foreign-vehicle/")!
    static let mibAbroad = URL(string: "https://www.mib.org.uk/driving-abroad/making-a-claim-road-traffic-accidents-abroad")!
    static let askMID = URL(string: "https://www.askmid.com/")!
    static let yourEuropeAccident = URL(string: "https://europa.eu/youreurope/citizens/vehicles/insurance/accident/index_en.htm")!
    static let franceConstat = URL(string: "https://www.service-public.gouv.fr/particuliers/vosdroits/F2149")!
}

enum AccidentLookupFlags {
    static func flags(
        from result: VehicleLookupResult,
        expectedMake: String? = nil,
        expectedColour: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Set<AccidentRedFlag> {
        flags(
            motStatus: result.motStatus,
            motExpiryDate: result.motExpiryDate,
            taxStatus: result.taxStatus,
            markedForExport: result.markedForExport ?? false,
            lookupMake: result.make,
            lookupColour: result.colour,
            expectedMake: expectedMake,
            expectedColour: expectedColour,
            now: now,
            calendar: calendar
        )
    }

    static func flags(
        motStatus: String?,
        motExpiryDate: Date?,
        taxStatus: String?,
        markedForExport: Bool,
        lookupMake: String?,
        lookupColour: String?,
        expectedMake: String? = nil,
        expectedColour: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Set<AccidentRedFlag> {
        var flags = Set<AccidentRedFlag>()
        if isInvalidMOT(motStatus: motStatus, motExpiryDate: motExpiryDate, now: now, calendar: calendar) {
            flags.insert(.invalidMOT)
        }
        if isSORN(taxStatus: taxStatus) {
            flags.insert(.sorn)
        } else if isUntaxed(taxStatus: taxStatus) {
            flags.insert(.untaxed)
        }
        if markedForExport {
            flags.insert(.markedForExport)
        }
        if isMismatch(lookup: lookupMake, confirmed: expectedMake)
            || isMismatch(lookup: lookupColour, confirmed: expectedColour) {
            flags.insert(.plateMismatch)
        }
        return flags
    }

    static func isInvalidMOT(
        motStatus: String?,
        motExpiryDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if let expiry = motExpiryDate, calendar.startOfDay(for: expiry) < calendar.startOfDay(for: now) {
            return true
        }
        let status = (motStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !status.isEmpty else { return false }
        if status.contains("valid") && !status.contains("not valid") && !status.contains("invalid") {
            return false
        }
        if status.contains("not valid") || status.contains("invalid") || status.contains("expired") {
            return true
        }
        return false
    }

    static func isSORN(taxStatus: String?) -> Bool {
        (taxStatus ?? "").localizedCaseInsensitiveContains("sorn")
    }

    static func isUntaxed(taxStatus: String?) -> Bool {
        let status = taxStatus ?? ""
        guard !isSORN(taxStatus: status) else { return false }
        return status.localizedCaseInsensitiveContains("untaxed")
            || status.localizedCaseInsensitiveContains("not taxed")
    }

    private static func isMismatch(lookup: String?, confirmed: String?) -> Bool {
        let left = normalizeCompare(lookup)
        let right = normalizeCompare(confirmed)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left != right && !left.contains(right) && !right.contains(left)
    }

    private static func normalizeCompare(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

enum AccidentGuidance {
    static let helperDisclaimer =
        "This is a helper for a stressful moment, not legal advice. Guidance is based on GOV.UK, police, MIB and European sources, but it cannot be correct for every country, force or circumstance. Follow local emergency services and your insurer."

    static func evaluate(_ input: AccidentGuidanceInput) -> AccidentGuidanceResult {
        let emergencyNumber = input.jurisdiction.emergencyNumber
        let shouldCallEmergencyNow = input.anyoneInjured
            || input.sceneUnsafeOrBlocked
            || input.suspectedImpairmentOrViolence
            || input.hitAndRun
        let ukPoliceFlags = input.redFlags.filter(\.raisesPoliceReportInUK)
        let shouldReportPolice: Bool = {
            if shouldCallEmergencyNow { return true }
            if input.jurisdiction.isUnitedKingdom {
                return !input.detailsExchanged
                    || input.anyoneInjured
                    || input.otherDriverRefused
                    || !ukPoliceFlags.isEmpty
            }
            if input.jurisdiction == .france {
                return input.anyoneInjured || input.otherDriverRefused || input.hitAndRun
            }
            if input.jurisdiction.isEuropeOrIreland {
                return input.anyoneInjured
                    || input.otherDriverRefused
                    || input.hitAndRun
                    || !input.detailsExchanged
            }
            return input.anyoneInjured || input.hitAndRun || !input.detailsExchanged
        }()

        let branch = processBranch(for: input, shouldReportPolice: shouldReportPolice)
        let photoKinds = photoKinds(for: input)
        let cards = cards(
            for: input,
            emergencyNumber: emergencyNumber,
            shouldCallEmergencyNow: shouldCallEmergencyNow,
            shouldReportPolice: shouldReportPolice,
            branch: branch
        )

        return AccidentGuidanceResult(
            emergencyNumber: emergencyNumber,
            shouldCallEmergencyNow: shouldCallEmergencyNow,
            shouldReportPolice: shouldReportPolice,
            policeNumber: input.jurisdiction.policeNonEmergencyNumber,
            shouldNotifyInsurer: true,
            processBranch: branch,
            cards: cards,
            photoKinds: photoKinds
        )
    }

    static func processBranch(
        for input: AccidentGuidanceInput,
        shouldReportPolice: Bool? = nil
    ) -> AccidentProcessBranch {
        switch input.jurisdiction {
        case .france:
            return .francePaperEAS
        case .ireland, .spain, .germany, .europeanUnion:
            return .europeEAS
        case .other:
            return .otherAbroad
        case .unitedKingdom:
            if input.otherVehicleIsForeign || input.redFlags.contains(.foreignPlate) {
                return .ukForeignVehicle
            }
            let report = shouldReportPolice ?? (
                !input.detailsExchanged
                    || input.anyoneInjured
                    || input.hitAndRun
                    || input.otherDriverRefused
                    || !input.redFlags.filter(\.raisesPoliceReportInUK).isEmpty
            )
            return report ? .ukPoliceFlag : .ukStandard
        }
    }

    static func photoKinds(for input: AccidentGuidanceInput) -> [AccidentPhotoKind] {
        var kinds: [AccidentPhotoKind] = [
            .positions,
            .damageOwn,
            .damageOther,
            .plate,
            .road,
            .documents
        ]
        let includeHitch = input.vehicleKind == .caravan || input.hasTowOrTrailer
        if includeHitch {
            kinds.insert(.hitch, at: 4)
            kinds.insert(.trailer, at: 5)
        }
        kinds.append(.other)
        return kinds
    }

    private static func cards(
        for input: AccidentGuidanceInput,
        emergencyNumber: String,
        shouldCallEmergencyNow: Bool,
        shouldReportPolice: Bool,
        branch: AccidentProcessBranch
    ) -> [AccidentGuidanceCard] {
        var cards: [AccidentGuidanceCard] = [
            AccidentGuidanceCard(
                id: "disclaimer",
                kind: .disclaimer,
                title: "Helper only",
                body: helperDisclaimer,
                callNumber: nil,
                linkURL: nil,
                linkTitle: nil
            ),
            AccidentGuidanceCard(
                id: "safety",
                kind: .safety,
                title: "Make the scene safer",
                body: "You should usually stop, switch on hazard lights, switch off the engine, and move yourself and others away from traffic if it is safe. Do not admit fault or speculate about what happened.",
                callNumber: nil,
                linkURL: nil,
                linkTitle: nil
            )
        ]

        if input.jurisdiction.isEuropeOrIreland || input.jurisdiction == .other {
            cards.append(
                AccidentGuidanceCard(
                    id: "hivis",
                    kind: .safety,
                    title: "High-visibility clothing",
                    body: "In many European countries you should put on a hi-vis jacket before stepping out. In Spain a V16 beacon is replacing the warning triangle. Follow what is required where you are.",
                    callNumber: nil,
                    linkURL: nil,
                    linkTitle: nil
                )
            )
        }

        if shouldCallEmergencyNow {
            let reason: String
            if input.anyoneInjured {
                reason = "Someone may be injured. Adrenaline can hide symptoms — check everyone again."
            } else if input.suspectedImpairmentOrViolence {
                reason = "If you suspect drink, drugs or violence, treat this as an emergency."
            } else if input.hitAndRun {
                reason = "If the other driver is leaving or has left, call emergency services while you still can."
            } else {
                reason = "If the road is blocked, there is fire, or people are in danger, call emergency services."
            }
            cards.append(
                AccidentGuidanceCard(
                    id: "emergency",
                    kind: .emergency,
                    title: "Call \(emergencyNumber)",
                    body: reason,
                    callNumber: emergencyNumber,
                    linkURL: nil,
                    linkTitle: nil
                )
            )
        }

        cards.append(
            AccidentGuidanceCard(
                id: "exchange",
                kind: .exchange,
                title: "Exchange details",
                body: input.jurisdiction.isUnitedKingdom
                    ? "You should usually exchange name, address, registration, and insurance details if asked. If the vehicle is not theirs, also note the owner’s name and address. Stay factual."
                    : "Write down the other driver’s name, address, phone, registration (and trailer if any), insurer, policy number and Green Card if they have one. Stay factual and do not admit liability.",
                callNumber: nil,
                linkURL: input.jurisdiction.isUnitedKingdom ? AccidentLinks.govUKAccident : AccidentLinks.yourEuropeAccident,
                linkTitle: input.jurisdiction.isUnitedKingdom ? "GOV.UK accident guidance" : "Your Europe accident guidance"
            )
        )

        let hasInvalidMOT = input.redFlags.contains(.invalidMOT)
        let hasSORN = input.redFlags.contains(.sorn)
        if hasInvalidMOT && hasSORN {
            cards.append(
                AccidentGuidanceCard(
                    id: "mot-sorn",
                    kind: .police,
                    title: "MOT expired and SORN",
                    body: "Lookup suggests this vehicle has an expired MOT and is SORN. A SORN vehicle should not be on a public road except for a pre-booked MOT. You should usually involve the police on 101 or online — not 999 unless there is danger. Still exchange details if you can, and tell your insurer. SORN is a stronger flag that they may also be uninsured; MIB may help if they are uninsured in the UK.",
                    callNumber: input.jurisdiction.isUnitedKingdom ? "101" : nil,
                    linkURL: AccidentLinks.govUKNoMOT,
                    linkTitle: "Report a vehicle with no MOT"
                )
            )
        } else if hasInvalidMOT {
            cards.append(
                AccidentGuidanceCard(
                    id: "mot",
                    kind: .police,
                    title: "MOT may not be valid",
                    body: "A vehicle used on a public road without a valid MOT is usually a police matter in the UK, not DVLA. This does not prove they are uninsured. You should usually still exchange details, then involve the police on 101 or online — not 999 unless there is danger. Tell your insurer.",
                    callNumber: input.jurisdiction.isUnitedKingdom ? "101" : nil,
                    linkURL: AccidentLinks.govUKNoMOT,
                    linkTitle: "Report a vehicle with no MOT"
                )
            )
        } else if hasSORN {
            cards.append(
                AccidentGuidanceCard(
                    id: "sorn",
                    kind: .police,
                    title: "Vehicle may be SORN",
                    body: "A SORN vehicle should not be on a public road except for a pre-booked MOT. That is a stronger flag that it may also be uninsured. You should usually involve the police on 101 or online — not 999 unless there is danger. Tell your insurer. MIB may be able to help if they are uninsured in the UK.",
                    callNumber: input.jurisdiction.isUnitedKingdom ? "101" : nil,
                    linkURL: AccidentLinks.govUKAccident,
                    linkTitle: "Uninsured motorists — GOV.UK"
                )
            )
        }

        if input.redFlags.contains(.untaxed) {
            cards.append(
                AccidentGuidanceCard(
                    id: "untaxed",
                    kind: .police,
                    title: "Vehicle may be untaxed",
                    body: "Untaxed use on a public road is a licensing offence. Consider reporting it and tell your insurer. Keep a photo of the plate and note when you checked.",
                    callNumber: input.jurisdiction.isUnitedKingdom ? "101" : nil,
                    linkURL: nil,
                    linkTitle: nil
                )
            )
        }

        if input.redFlags.contains(.markedForExport) {
            cards.append(
                AccidentGuidanceCard(
                    id: "export",
                    kind: .police,
                    title: "Marked for export",
                    body: "Lookup suggests this vehicle is marked for export. Treat that as a red flag, photograph the plate, and tell police and your insurer.",
                    callNumber: input.jurisdiction.isUnitedKingdom ? "101" : nil,
                    linkURL: nil,
                    linkTitle: nil
                )
            )
        }

        if input.redFlags.contains(.plateMismatch) {
            cards.append(
                AccidentGuidanceCard(
                    id: "mismatch",
                    kind: .police,
                    title: "Plate may not match the vehicle",
                    body: "Make or colour from lookup does not match what you recorded. If it is safe, consider calling 101 while you are still at the scene.",
                    callNumber: input.jurisdiction.isUnitedKingdom ? "101" : nil,
                    linkURL: nil,
                    linkTitle: nil
                )
            )
        }

        if input.redFlags.contains(.suspectedUninsured) || (!input.insuranceCertificateSeen && input.anyoneInjured) {
            cards.append(
                AccidentGuidanceCard(
                    id: "uninsured",
                    kind: .insurer,
                    title: "Insurance could not be confirmed",
                    body: "This app cannot check another vehicle’s insurance. Ask to see a certificate or Green Card. If they refuse, or you have an injury accident, you should usually report to police. In the UK, askMID can check another vehicle after an accident for a fee.",
                    callNumber: input.jurisdiction.isUnitedKingdom && shouldReportPolice ? "101" : nil,
                    linkURL: AccidentLinks.askMID,
                    linkTitle: "askMID"
                )
            )
        }

        if shouldReportPolice && !shouldCallEmergencyNow {
            let number = input.jurisdiction.policeNonEmergencyNumber ?? emergencyNumber
            cards.append(
                AccidentGuidanceCard(
                    id: "police",
                    kind: .police,
                    title: "Consider reporting to police",
                    body: input.jurisdiction.isUnitedKingdom
                        ? "You should usually report to police within 24 hours if details were not exchanged, anyone was injured, or a driving offence is suspected. Use 101 or report online if it is not an emergency."
                        : "If anyone is hurt, the other driver will not cooperate, or you cannot agree the facts, you should usually involve local police. Keep any incident number.",
                    callNumber: number,
                    linkURL: input.jurisdiction.isUnitedKingdom ? AccidentLinks.metPoliceCollisions : nil,
                    linkTitle: input.jurisdiction.isUnitedKingdom ? "Police collision advice" : nil
                )
            )
        }

        switch branch {
        case .francePaperEAS:
            cards.append(
                AccidentGuidanceCard(
                    id: "france-eas",
                    kind: .eas,
                    title: "Use a paper European Accident Statement",
                    body: "France’s e-constat app usually cannot be used when one vehicle is registered outside France. Complete a paper European Accident Statement (constat amiable) if you can. Signing records agreed facts, not liability — do not sign if you do not understand it.",
                    callNumber: nil,
                    linkURL: AccidentLinks.franceConstat,
                    linkTitle: "French official guidance"
                )
            )
        case .europeEAS:
            cards.append(
                AccidentGuidanceCard(
                    id: "eas",
                    kind: .eas,
                    title: "European Accident Statement",
                    body: "If you can, complete a European Accident Statement with the other driver. The layout is the same in every language. Signing means you agree the recorded facts, not that you accept blame. Each of you keeps a copy for your insurer.",
                    callNumber: nil,
                    linkURL: AccidentLinks.yourEuropeAccident,
                    linkTitle: "Your Europe"
                )
            )
        case .ukForeignVehicle:
            cards.append(
                AccidentGuidanceCard(
                    id: "foreign-uk",
                    kind: .note,
                    title: "Foreign vehicle in the UK",
                    body: "UK rules still apply. Ask for a Green Card number if they have one. The registration number is the minimum. Your claim is usually handled by the foreign insurer’s UK representative, or MIB if you cannot identify them.",
                    callNumber: nil,
                    linkURL: AccidentLinks.mibForeignInUK,
                    linkTitle: "MIB — foreign vehicle in the UK"
                )
            )
        case .otherAbroad:
            cards.append(
                AccidentGuidanceCard(
                    id: "abroad",
                    kind: .note,
                    title: "Accident outside Europe",
                    body: "Local law applies. Call local emergency services if needed, photograph everything, and contact your insurer as soon as you can. You may need a Green Card. Protection for uninsured or untraced drivers varies widely.",
                    callNumber: emergencyNumber,
                    linkURL: AccidentLinks.mibAbroad,
                    linkTitle: "MIB — accidents abroad"
                )
            )
        case .ukStandard, .ukPoliceFlag:
            break
        }

        if input.jurisdiction.isEuropeOrIreland || input.jurisdiction == .other {
            cards.append(
                AccidentGuidanceCard(
                    id: "brexit-claim",
                    kind: .note,
                    title: "Claiming from the UK after Brexit",
                    body: "UK residents usually cannot claim through UK MIB visiting-victims for an accident abroad. You typically claim against the foreign insurer, or that country’s guarantee fund if they are uninsured or untraced. MIB can still signpost. Your own comprehensive cover abroad matters more than before.",
                    callNumber: nil,
                    linkURL: AccidentLinks.mibAbroad,
                    linkTitle: "MIB accidents abroad"
                )
            )
        }

        cards.append(
            AccidentGuidanceCard(
                id: "photos",
                kind: .photos,
                title: "Photograph what you can",
                body: "Insurers rely on photos: vehicle positions before moving if safe, damage, every plate, hitch and trailer if relevant, road layout, signs and debris. Note time, weather and location.",
                callNumber: nil,
                linkURL: nil,
                linkTitle: nil
            )
        )

        cards.append(
            AccidentGuidanceCard(
                id: "insurer",
                kind: .insurer,
                title: "Tell your insurer",
                body: "You should report the accident to your insurer even if you do not plan to claim. Do this as soon as you reasonably can.",
                callNumber: nil,
                linkURL: nil,
                linkTitle: nil
            )
        )

        return cards
    }
}
