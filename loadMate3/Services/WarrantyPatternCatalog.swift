import Foundation

struct WarrantyServiceWindow: Equatable {
    let daysBefore: Int
    let daysAfter: Int
}

struct WarrantyReferenceLink: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL

    init(title: String, urlString: String) {
        self.id = urlString
        self.title = title
        self.url = URL(string: urlString)!
    }
}

struct WarrantyManufacturerHelp: Equatable {
    let coverSummary: String
    let annualServiceRules: String
    let whatEachServiceMeans: String
    let subsequentOwnership: String
    let starterDisclaimer: String
    let referenceLinks: [WarrantyReferenceLink]
}

struct WarrantyManufacturerTemplate: Identifiable, Equatable {
    let id: String
    let displayName: String
    let manufacturerName: String
    let summary: String
    let durationYears: Int
    let defaultDaysBefore: Int
    let defaultDaysAfter: Int
    let milestoneYears: Set<Int>
    let milestoneDaysBefore: Int?
    let help: WarrantyManufacturerHelp?

    var isCustom: Bool { id == WarrantyPatternCatalog.customID }

    func window(forYear year: Int) -> WarrantyServiceWindow {
        if milestoneYears.contains(year) {
            return WarrantyServiceWindow(
                daysBefore: milestoneDaysBefore ?? defaultDaysBefore,
                daysAfter: 0
            )
        }
        return WarrantyServiceWindow(daysBefore: defaultDaysBefore, daysAfter: defaultDaysAfter)
    }

    func serviceType(forYear year: Int) -> WarrantyServiceType {
        if milestoneYears.contains(year) {
            return .serviceWithBodyCheck
        }
        return .normalService
    }

    func requirement(forYear year: Int) -> String {
        let base = "Annual habitation service including damp/moisture survey. Keep the VAT invoice and damp report as evidence."
        if milestoneYears.contains(year) {
            return "\(base) Milestone year \(year): complete on or before the anniversary — no after-grace under typical published terms."
        }
        return "\(base) Confirm exact window and scope with your handbook."
    }
}

/// Backwards-compatible alias used by existing call sites.
typealias WarrantyCommonPattern = WarrantyManufacturerTemplate

/// Starter warranty schedules for touring caravans.
/// Motorhome / campervan starters live in `MotorhomeWarrantyPatternCatalog` for a later vehicle-kind-aware merge.
enum WarrantyPatternCatalog {
    static let customID = "custom"

    static let starterDisclaimer = """
    This is a starter schedule based on commonly published UK / Northern Ireland manufacturer guidance. It is for organisation only and may not match EU or other markets. Confirm every interval, window and requirement with your owner's handbook and dealer before relying on it.
    """

    static let all: [WarrantyManufacturerTemplate] = [
        custom,
        swift,
        bailey,
        coachman,
        elddis,
        adria,
    ]

    static var pickerOptions: [WarrantyManufacturerTemplate] { all }

    static func pickerOptions(ukMarket: Bool) -> [WarrantyManufacturerTemplate] {
        ukMarket ? all : [custom]
    }

    static var manufacturerGuides: [WarrantyManufacturerTemplate] {
        all.filter { !$0.isCustom }
    }

    static func pattern(id: String?) -> WarrantyManufacturerTemplate? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func patternOrCustom(id: String?) -> WarrantyManufacturerTemplate {
        if let id, let match = all.first(where: { $0.id == id }) {
            return match
        }
        return custom
    }

    // MARK: - Templates

    private static let custom = WarrantyManufacturerTemplate(
        id: customID,
        displayName: "Custom (set duration yourself)",
        manufacturerName: "",
        summary: "Choose your own plan length and edit each milestone after creation. Default window is 60 days before and 30 days after.",
        durationYears: WarrantySupport.defaultDurationYears,
        defaultDaysBefore: WarrantySupport.defaultDaysBefore,
        defaultDaysAfter: WarrantySupport.defaultDaysAfter,
        milestoneYears: [],
        milestoneDaysBefore: nil,
        help: nil
    )

    private static let swift = WarrantyManufacturerTemplate(
        id: "swift",
        displayName: "Swift",
        manufacturerName: "Swift",
        summary: "10-year starter: SuperSure-style parts cover plus body cover milestones. Normal window 90 days before / 60 days after; years 3, 6 and 10 must finish on or before the anniversary.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 60,
        milestoneYears: [3, 6, 10],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Swift touring cover includes a 3-year parts/fittings warranty (often called SuperSure), a 6-year body shell warranty, and a 10-year extended body shell warranty for the first registered owner. Exact names and exclusions vary by model year — check your handbook.
            """,
            annualServiceRules: """
            Annual service is normally allowed within 90 days before or 60 days after each purchase anniversary. To preserve the 3-, 6- and 10-year covers, the 3rd, 6th and 10th annual services must be completed before those warranty periods expire (on or before the anniversary — no after-grace on those milestone years). Keep original VAT invoices.
            """,
            whatEachServiceMeans: """
            Each annual inspection is a habitation service with damp/moisture checks and the items listed in the Swift annual service checklist. Use an authorised Swift Group service centre or an NCC Approved Workshop Scheme (AWS) engineer covering the required items. Proof of service is needed for warranty work and for transfer.
            """,
            subsequentOwnership: """
            Unexpired cover may transfer if service history is complete, but the extended 10-year body shell benefit is typically first-owner only and non-transferable. Always confirm transfer rules for your model year.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Swift Group — owners / warranty information",
                    urlString: "https://www.swiftgroup.co.uk/"
                ),
                WarrantyReferenceLink(
                    title: "Swift leisure help — what is covered",
                    urlString: "https://swiftleisurehelp.zendesk.com/hc/en-gb/articles/25473946519441-What-is-covered"
                ),
            ]
        )
    )

    private static let bailey = WarrantyManufacturerTemplate(
        id: "bailey",
        displayName: "Bailey",
        manufacturerName: "Bailey",
        summary: "6-year starter aligned to body-shell integrity cover. Normal window about 6 weeks either side; final services of each cover period must finish on or before the anniversary.",
        durationYears: 6,
        defaultDaysBefore: 42,
        defaultDaysAfter: 42,
        milestoneYears: [3, 6],
        milestoneDaysBefore: 42,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Bailey touring cover includes a 3-year manufacturer's warranty and a 6-year body-shell integrity warranty against structural degradation from water ingress through permanently sealed seams/joints. Optional longer body cover has been offered historically — check your documents.
            """,
            annualServiceRules: """
            Annual services are normally allowed within six weeks either side of the purchase anniversary. The final annual service of any warranty period must be carried out on or before the anniversary/end of that period. Keep original VAT invoices as proof.
            """,
            whatEachServiceMeans: """
            Full annual service and inspection including a moisture survey. Prefer an Approved Bailey Retailer/Service Centre; NCC AWS workshops are also commonly accepted. Repairs identified at inspection usually need to be made available within about six weeks.
            """,
            subsequentOwnership: """
            Remaining cover is often transferable with Bailey's consent, payment of a transfer fee, and proof of annual servicing within a short window after re-sale. Confirm current transfer rules with Bailey or your dealer.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Bailey — warranties and servicing",
                    urlString: "https://www.baileyofbristol.co.uk/warranties-servicing/"
                ),
            ]
        )
    )

    private static let coachman = WarrantyManufacturerTemplate(
        id: "coachman",
        displayName: "Coachman",
        manufacturerName: "Coachman",
        summary: "10-year starter with water-ingress milestones. Normal window often 90 days either side; years 3, 6 and 10 must finish before the anniversary.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [3, 6, 10],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Coachman cover includes a 3-year manufacturer's warranty and, for many models from around 2015 onwards, a 10-year water ingress warranty for the first owner (conditions apply for years 6–10). Check your Service, Warranty & Technical Data handbook for your year.
            """,
            annualServiceRules: """
            A full annual service is required. Interim years commonly allow about 90 days either side of the anniversary. To preserve longer water-ingress cover, the 3rd, 6th and 10th services must usually be completed before the anniversary. Retain VAT invoices and damp reports; keep the annual service record stamped.
            """,
            whatEachServiceMeans: """
            Habitation service and safety check in line with NCC recommendations, including damp reporting. The supplying dealership is typically responsible for warranty repairs; other approved workshops may help at their discretion.
            """,
            subsequentOwnership: """
            Unexpired manufacturer and water-ingress terms may transfer with conditions and service history. Milestone services (3rd/6th/10th) still matter for later water-ingress cover. Confirm with Coachman/your dealer for your VIN and handbook year.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Coachman Caravan Company",
                    urlString: "https://www.coachman.co.uk/"
                ),
            ]
        )
    )

    private static let elddis = WarrantyManufacturerTemplate(
        id: "elddis",
        displayName: "Elddis (incl. Compass, Buccaneer, Xplore)",
        manufacturerName: "Elddis",
        summary: "10-year starter. Years 1–2 and 4–9 use ±60 days; years 3 and 10 must finish within 60 days before the anniversary (no after-grace). No service gap over 14 months.",
        durationYears: 10,
        defaultDaysBefore: 60,
        defaultDaysAfter: 60,
        milestoneYears: [3, 10],
        milestoneDaysBefore: 60,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Elddis / Compass / Buccaneer / Xplore cover includes a 3-year manufacturer's warranty and a 10-year water ingress and body integrity warranty (water ingress through permanently sealed joints). Fiat-based motorhomes may differ on base-vehicle cover. Always use the handbook for your exact model year.
            """,
            annualServiceRules: """
            Annual service and damp check by an approved Elddis/Compass/Xplore/Buccaneer retailer or service centre. Years 1, 2 and 4–9: no more than 60 days either side of the purchase anniversary. Years 3 and 10: no more than 60 days before the anniversary (not after). No service interval should exceed 14 months. Keep original VAT invoices and damp reports.
            """,
            whatEachServiceMeans: """
            Habitation service plus damp check. If repairs are identified, the vehicle is usually expected to be made available for repair within about six weeks. Warranty work should follow manufacturer approval routes.
            """,
            subsequentOwnership: """
            Remaining cover for used/subsequent ownership is often capped (for example up to six years' water ingress/body integrity from the original purchase date). Transfer may require registration and proof of servicing. Confirm current rules with Elddis.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Elddis — warranty information",
                    urlString: "https://elddis.co.uk/help-support/warranty-information"
                ),
            ]
        )
    )

    private static let adria = WarrantyManufacturerTemplate(
        id: "adria",
        displayName: "Adria",
        manufacturerName: "Adria",
        summary: "10-year starter for water ingress cover. Normal window about 3 months either side; final services of each cover period must finish before that period ends.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [2, 10],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Adria UK cover includes a 2-year manufacturer's warranty and a 10-year water ingress warranty against structural degradation from water ingress through permanently sealed seams/joints. Confirm your model year documents.
            """,
            annualServiceRules: """
            Full annual service and moisture survey required. Other services are often allowed within three months either side of the purchase anniversary. The final service of any warranty period must be completed before that period ends. Invoices should be retained; many dealers also register the inspection on Adria's portal.
            """,
            whatEachServiceMeans: """
            Habitation service including moisture survey by an Authorised Adria Service Centre or NCC AWS member. Follow dealer guidance for booking and portal registration.
            """,
            subsequentOwnership: """
            The 10-year water ingress warranty is often described as transferable, subject to continuous annual servicing and registration. Confirm transfer steps with your Adria dealer.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Adria UK — warranty",
                    urlString: "https://www.adria.co.uk/adria-warranty"
                ),
            ]
        )
    )
}
