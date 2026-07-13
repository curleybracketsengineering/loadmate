import Foundation

/// Starter warranty schedules for motorhomes / campervans (LoadMate's self-propelled leisure vehicles).
/// Not yet wired into the warranty picker — kept as a source for a later vehicle-kind-aware integration.
enum MotorhomeWarrantyPatternCatalog {
    static let customID = WarrantyPatternCatalog.customID

    static let starterDisclaimer = WarrantyPatternCatalog.starterDisclaimer

    static let all: [WarrantyManufacturerTemplate] = [
        custom,
        swift,
        bailey,
        baileyCampervan,
        coachman,
        elddis,
        adria,
        autoTrail,
        chausson,
        burstner,
        hobby,
    ]

    static var pickerOptions: [WarrantyManufacturerTemplate] { all }

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
        summary: "10-year starter: SuperSure-style habitation parts cover plus body cover milestones. Normal window 90 days before / 60 days after; years 3, 6 and 10 must finish on or before the anniversary. Base vehicle (Fiat/Ford) is separate.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 60,
        milestoneYears: [3, 6, 10],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Swift coachbuilt motorhome cover includes a 3-year SuperSure warranty on habitation parts/fittings, a 6-year body shell warranty, and a 10-year extended body shell warranty for the first registered owner. The Fiat or Ford base vehicle has its own manufacturer warranty and service schedule — Swift habitation cover does not replace it. Exact names and exclusions vary by model year.
            """,
            annualServiceRules: """
            The habitation area normally needs an annual service within 90 days before or 60 days after each purchase anniversary. To preserve SuperSure / body / extended body cover, the 3rd, 6th and 10th annual habitation services must be completed before those warranty periods expire (on or before the anniversary — no after-grace on those milestone years). Keep original VAT invoices. Follow the base-vehicle handbook for chassis/engine servicing.
            """,
            whatEachServiceMeans: """
            Each annual inspection is a habitation service with damp/moisture checks and the items listed in the Swift annual service checklist. Use an authorised Swift Group service centre or an NCC Approved Workshop Scheme (AWS) engineer covering the required items. Proof of service is needed for warranty work and for transfer.
            """,
            subsequentOwnership: """
            Unexpired SuperSure and 6-year body cover may transfer if service history is complete, but the extended 10-year body shell benefit is typically first-owner only and non-transferable. Always confirm transfer rules for your model year.
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
        displayName: "Bailey (coachbuilt motorhome)",
        manufacturerName: "Bailey",
        summary: "6-year starter aligned to coachbuilt bodyshell integrity cover. Normal window about 6 weeks either side; final services of each cover period must finish on or before the anniversary. Base vehicle is separate.",
        durationYears: 6,
        defaultDaysBefore: 42,
        defaultDaysAfter: 42,
        milestoneYears: [3, 6],
        milestoneDaysBefore: 42,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Bailey coachbuilt motorhome cover includes a 3-year manufacturer's warranty and a 6-year bodyshell integrity warranty against structural degradation from water ingress through permanently sealed seams/joints. Optional longer body cover has been offered historically. The Fiat/Peugeot/Ford base vehicle has its own warranty — confirm your handbook. Campervan conversions often use shorter body cover (see Bailey Campervan).
            """,
            annualServiceRules: """
            Annual habitation services are normally allowed within six weeks either side of the purchase anniversary. The final annual habitation service of any warranty period must be carried out on or before the anniversary/end of that period. Keep original VAT invoices as proof. Service the base vehicle to its manufacturer schedule.
            """,
            whatEachServiceMeans: """
            Full annual habitation service and inspection including a moisture survey. Prefer an Approved Bailey Retailer/Service Centre; NCC AWS workshops are also commonly accepted. Repairs identified at inspection usually need to be made available within about six weeks.
            """,
            subsequentOwnership: """
            Remaining Bailey cover is often transferable with consent, a transfer fee, and proof of annual servicing within a short window after re-sale. Confirm current transfer rules with Bailey or your dealer.
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

    private static let baileyCampervan = WarrantyManufacturerTemplate(
        id: "bailey-campervan",
        displayName: "Bailey (campervan)",
        manufacturerName: "Bailey",
        summary: "3-year starter for Bailey campervan conversion/bodyshell cover. Normal window about 6 weeks either side; year 3 must finish on or before the anniversary. Ford base vehicle is separate.",
        durationYears: 3,
        defaultDaysBefore: 42,
        defaultDaysAfter: 42,
        milestoneYears: [3],
        milestoneDaysBefore: 42,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Bailey campervan cover includes a 3-year manufacturer's warranty and a 3-year bodyshell integrity warranty on the van conversion (water ingress), which is shorter than Bailey's coachbuilt motorhome body cover. The Ford base vehicle has its own manufacturer warranty and is not covered by Bailey's campervan warranty.
            """,
            annualServiceRules: """
            Annual habitation services are normally allowed within six weeks either side of the purchase anniversary. The final annual habitation service of any warranty period must be carried out on or before the anniversary/end of that period. Keep original VAT invoices. Follow Ford's schedule for the base vehicle.
            """,
            whatEachServiceMeans: """
            Full annual habitation service and inspection including a moisture survey by an Authorised Bailey Service Centre or NCC AWS member. Repairs identified at inspection usually need to be made available within about six weeks.
            """,
            subsequentOwnership: """
            Confirm transfer rules with Bailey or your dealer — remaining cover is often transferable subject to servicing history and registration steps.
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
        summary: "10-year starter with water-ingress milestones for Coachman motorhomes. Normal window often 90 days either side; years 3, 6 and 10 must finish before the anniversary. Mercedes base vehicle is separate.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [3, 6, 10],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Coachman motorhome cover includes a 3-year manufacturer's warranty on habitation parts/components and a 10-year water ingress warranty for the coachbuilt body (conditions apply for later years). Mercedes provides a separate base-vehicle warranty — check that handbook for chassis/engine terms.
            """,
            annualServiceRules: """
            A full annual habitation service is required. Interim years commonly allow about 90 days either side of the anniversary. To preserve longer water-ingress cover, the 3rd, 6th and 10th services must usually be completed before the anniversary. Retain VAT invoices and damp reports; keep the annual service record stamped.
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
                    title: "Coachman — guarantees",
                    urlString: "https://www.coachman.co.uk/explore-our-guarantees/"
                ),
            ]
        )
    )

    private static let elddis = WarrantyManufacturerTemplate(
        id: "elddis",
        displayName: "Elddis (incl. Compass, Buccaneer, Autoquest)",
        manufacturerName: "Elddis",
        summary: "10-year starter. Years 1–2 and 4–9 use ±60 days; years 3 and 10 must finish within 60 days before the anniversary (no after-grace). No service gap over 14 months. Fiat-based models may have shorter parts cover.",
        durationYears: 10,
        defaultDaysBefore: 60,
        defaultDaysAfter: 60,
        milestoneYears: [3, 10],
        milestoneDaysBefore: 60,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Elddis / Compass / Buccaneer motorhome and campervan cover includes a 3-year manufacturer's warranty (often 2 years on Fiat-based vehicles) and a 10-year water ingress and body integrity warranty through permanently sealed joints. The base vehicle has its own Fiat/Peugeot (or other) warranty. Always use the handbook for your exact model year.
            """,
            annualServiceRules: """
            Annual habitation service and damp check by an approved Elddis/Compass/Xplore/Buccaneer retailer or service centre. Years 1, 2 and 4–9: no more than 60 days either side of the purchase anniversary. Years 3 and 10: no more than 60 days before the anniversary (not after). No service interval should exceed 14 months. Keep original VAT invoices and damp reports.
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
        summary: "10-year starter for water ingress cover. Normal window about 3 months either side; final services of each cover period must finish before that period ends. Base vehicle is separate.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [2, 10],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Adria UK cover includes a 2-year manufacturer's warranty and a 10-year water ingress warranty against structural degradation from water ingress through permanently sealed seams/joints. Chassis/base vehicle cover follows Fiat, Mercedes or other supplier terms. Confirm your model year documents.
            """,
            annualServiceRules: """
            Full annual habitation service and moisture survey required. Other services are often allowed within three months either side of the purchase anniversary. The final service of any warranty period must be completed before that period ends. Invoices should be retained; many dealers also register the inspection on Adria's portal.
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

    private static let autoTrail = WarrantyManufacturerTemplate(
        id: "auto-trail",
        displayName: "Auto-Trail",
        manufacturerName: "Auto-Trail",
        summary: "5-year starter for conversion and body integrity cover. Habitation window ±30 days; year 5 must finish on or before the anniversary. Fiat/Ford base vehicle is separate.",
        durationYears: 5,
        defaultDaysBefore: 30,
        defaultDaysAfter: 30,
        milestoneYears: [5],
        milestoneDaysBefore: 30,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Auto-Trail cover includes a conversion warranty (broader in years 1–2, selected habitation components in years 3–5) and a 5-year body integrity warranty for water ingress through permanent/fixed seam or sealed joints. Fiat- or Ford-based chassis cover is provided by the base-vehicle manufacturer, not Auto-Trail.
            """,
            annualServiceRules: """
            Annual habitation service within ±30 days of each anniversary of the original registration date. The 5th annual service must be completed before the end of the 60-month period from purchase (on or before that anniversary — no after-grace on year 5). Keep original VAT invoices, check sheets and damp reports. Chassis/engine servicing follows Fiat or Ford requirements.
            """,
            whatEachServiceMeans: """
            Habitation service by an Auto-Trail Service Centre, Auto-Trail dealer (preferably the selling dealer), or a VAT-registered NCC AWS workshop. Repairs identified at service that fall under Auto-Trail warranty usually need an authorised Auto-Trail centre within about six weeks.
            """,
            subsequentOwnership: """
            Auto-Trail warranties typically follow the vehicle; complete service history must pass to the new owner or cover may lapse. Confirm current transfer practice with Auto-Trail or your dealer.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Auto-Trail — warranty terms",
                    urlString: "https://www.auto-trail.co.uk/warranty-terms-and-conditions/"
                ),
                WarrantyReferenceLink(
                    title: "Auto-Trail — servicing",
                    urlString: "https://www.auto-trail.co.uk/servicing/"
                ),
            ]
        )
    )

    private static let chausson = WarrantyManufacturerTemplate(
        id: "chausson",
        displayName: "Chausson",
        manufacturerName: "Chausson",
        summary: "7-year starter for water-tightness cover on overcab/low-profile lines. Annual certified-network check required; exact day window often not published — starter uses ±90 days. Parts cover is typically 2 years. Base vehicle is separate.",
        durationYears: 7,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [7],
        milestoneDaysBefore: 90,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Chausson cover includes about 2 years parts and labour on the living compartment, plus a 7-year water-tightness guarantee on overcab and low-profile coachbuilt models (annual check by a certified Chausson network member). Campervan lines may differ — check your documents. The carrier/base vehicle is covered by Fiat, Ford or other chassis maker terms.
            """,
            annualServiceRules: """
            An annual habitation / water-tightness check by a certified Chausson network member is required to keep the 7-year water-tightness cover. Missing a year commonly voids cover for that period. Exact before/after day windows are not always published — this starter uses ±90 days and treats year 7 as finish-on-or-before; confirm your handbook and book early.
            """,
            whatEachServiceMeans: """
            Habitation and water-tightness inspection through a Chausson dealer or certified workshop. Chassis maintenance stays with the base-vehicle manufacturer's network.
            """,
            subsequentOwnership: """
            Water-tightness cover is often described as following the vehicle if the annual inspection history is complete. Confirm transfer steps with your Chausson dealer.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Chausson — warranty",
                    urlString: "https://www.chausson-motorhomes.com/after-sales-service/warranty/"
                ),
            ]
        )
    )

    private static let burstner = WarrantyManufacturerTemplate(
        id: "burstner",
        displayName: "Bürstner",
        manufacturerName: "Bürstner",
        summary: "10-year starter for leakproof/water-ingress cover (typical 2019–2025 model years; many 2026+ models are 6 years — edit duration). Window ±3 months. Manufacturer parts cover is typically 2 years.",
        durationYears: 10,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [],
        milestoneDaysBefore: nil,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            Typical published Bürstner cover includes about 2 years manufacturer's warranty plus a leakproof / water-ingress (tightness) guarantee. Duration depends on model year: often 10 years for 2019–2025 motorhomes/campervans (km caps may apply), with shorter cover on older or newer seasons (for example 6 years from many 2026 models). Confirm your exact year. Base vehicle warranty is separate.
            """,
            annualServiceRules: """
            An annual leakage / tightness test by an authorised Bürstner dealer is required. Published guidance commonly allows completion within 3 months before or after the warranty anniversary. Missed tests typically cause irreversible loss of the tightness guarantee. Keep the test reports.
            """,
            whatEachServiceMeans: """
            Authorised Bürstner dealer leakage test (often alongside habitation checks). Follow dealer guidance for documentation and any portal registration.
            """,
            subsequentOwnership: """
            The tightness guarantee is often described as transferring automatically with the vehicle on resale when the annual test history is intact. Confirm with your Bürstner partner.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Bürstner — tightness guarantee basics",
                    urlString: "https://helpcenter.buerstner.com/hc/en-gb/articles/30087845816093-Tightness-guarantee-Basics-Conditions"
                ),
                WarrantyReferenceLink(
                    title: "Bürstner — warranties overview",
                    urlString: "https://www.buerstner.com/de/en/service/warranties"
                ),
            ]
        )
    )

    private static let hobby = WarrantyManufacturerTemplate(
        id: "hobby",
        displayName: "Hobby",
        manufacturerName: "Hobby",
        summary: "12-year starter for watertightness cover on 2024-season-onwards models (older seasons were often 5 years — edit duration). Annual authorised dealer inspection required; exact day window often not published — starter uses ±90 days.",
        durationYears: 12,
        defaultDaysBefore: 90,
        defaultDaysAfter: 90,
        milestoneYears: [],
        milestoneDaysBefore: nil,
        help: WarrantyManufacturerHelp(
            coverSummary: """
            From the 2024 season onwards, Hobby typically publishes a 12-year watertightness guarantee on body-shell joints for new caravans and motorhomes (older seasons were commonly around 5 years). Parts/manufacturer cover lengths vary — check your handbook. Chassis/base vehicle terms remain with the carrier manufacturer.
            """,
            annualServiceRules: """
            An annual watertightness inspection by an authorised Hobby dealer is required, documented with an official test report. Exact before/after day windows are not always published — this starter uses ±90 days; confirm your documents and set reminders (Hobby's members area can help). Missed annual checks typically invalidate the watertightness guarantee.
            """,
            whatEachServiceMeans: """
            Dealer inspection of roof, windows, doors, joints and seals for leaks, logged in a test report. Combine with habitation servicing as your dealer recommends.
            """,
            subsequentOwnership: """
            Confirm whether remaining watertightness cover transfers with continuous annual inspection history for your model year.
            """,
            starterDisclaimer: starterDisclaimer,
            referenceLinks: [
                WarrantyReferenceLink(
                    title: "Hobby — watertightness guarantee",
                    urlString: "https://www.hobby-caravan.de/int_en/company/why-choosing-hobby-makes-sense/watertightness-guarantee/"
                ),
            ]
        )
    )
}
