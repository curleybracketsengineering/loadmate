import Foundation

enum SafetyCheckStatus: Equatable {
    case complete
    case due
}

struct SafetyCheckItem: Identifiable, Equatable {
    let id: String
    let title: String
    let status: SafetyCheckStatus
}

struct SafetyActivityItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isWarning: Bool
}

enum SafetySupport {
    static func todayChecklist(
        profile: VehicleProfile?,
        caravanSummary: WeightSummary?,
        motorhomeSummary: MotorhomeWeightSummary?,
        checklistSections: [ChecklistSection],
        tyreRecords: [TyreRecord]
    ) -> [SafetyCheckItem] {
        let kind = profile?.kind ?? .caravan
        var items: [SafetyCheckItem] = []

        let loadOK: Bool = {
            switch kind {
            case .caravan:
                guard let summary = caravanSummary else { return false }
                return !summary.isOverMTPLM && summary.isOverallSafe
            case .motorhome:
                return motorhomeSummary?.isOverallSafe ?? false
            }
        }()
        items.append(SafetyCheckItem(id: "load", title: "Load within limits", status: loadOK ? .complete : .due))

        switch kind {
        case .caravan:
            let noseOK: Bool = {
                guard let summary = caravanSummary else { return false }
                return !summary.isNoseBelowRecommended
                    && !summary.isNoseAboveRecommended
                    && !summary.isOverTowBallLimit
            }()
            items.append(SafetyCheckItem(
                id: "nose",
                title: "Nose weight within range",
                status: noseOK ? .complete : .due
            ))

        case .motorhome:
            if profile?.usesManualTowBarLoad == true {
                let towBarOK: Bool = {
                    guard let summary = motorhomeSummary else { return false }
                    return !summary.isOverTowBarLimit && !summary.isTowBarMeasurementMissing
                }()
                items.append(SafetyCheckItem(
                    id: "nose",
                    title: "Tow ball within range",
                    status: towBarOK ? .complete : .due
                ))
            }
        }

        let tyrePressureOK = tyreRecords.isEmpty
            ? false
            : tyreRecords.allSatisfy { $0.pressureAssessment.level == .current }
        items.append(SafetyCheckItem(
            id: "tyre-pressure",
            title: "Tyre pressures checked",
            status: tyrePressureOK ? .complete : .due
        ))

        switch kind {
        case .caravan:
            let hitchOK = ChecklistProgress.isGroupComplete(
                in: checklistSections,
                sectionTitle: "Towing setup",
                groupTitle: "Hitch & safety"
            )
            items.append(SafetyCheckItem(
                id: "hitch",
                title: "Hitch & breakaway cable",
                status: hitchOK ? .complete : .due
            ))

            let lightsOK = ChecklistProgress.isGroupComplete(
                in: checklistSections,
                sectionTitle: "Towing setup",
                groupTitle: "Moving off checks"
            )
            items.append(SafetyCheckItem(
                id: "lights",
                title: "Lights & indicators",
                status: lightsOK ? .complete : .due
            ))

            let doorsOK = ChecklistProgress.isSectionComplete(
                in: checklistSections,
                title: "Pitching",
                emptyMeansComplete: true
            )
            items.append(SafetyCheckItem(
                id: "doors",
                title: "Doors, windows & rooflights",
                status: doorsOK ? .complete : .due
            ))

        case .motorhome:
            let lightsOK = ChecklistProgress.isGroupComplete(
                in: checklistSections,
                sectionTitle: "Departure",
                groupTitle: "Final checks"
            )
            items.append(SafetyCheckItem(
                id: "lights",
                title: "Lights & indicators",
                status: lightsOK ? .complete : .due
            ))

            let doorsOK = ChecklistProgress.isGroupComplete(
                in: checklistSections,
                sectionTitle: "Before leaving home",
                groupTitle: "Exterior & chassis"
            )
            items.append(SafetyCheckItem(
                id: "doors",
                title: "Doors, windows & rooflights",
                status: doorsOK ? .complete : .due
            ))
        }

        return items
    }

    static func isReadyToTravel(checklist: [SafetyCheckItem]) -> Bool {
        checklist.allSatisfy { $0.status == .complete }
    }

    static func dueCount(in checklist: [SafetyCheckItem]) -> Int {
        checklist.filter { $0.status == .due }.count
    }

    static func completedCount(in checklist: [SafetyCheckItem]) -> Int {
        checklist.filter { $0.status == .complete }.count
    }

    static func recentActivity(from checklist: [SafetyCheckItem]) -> [SafetyActivityItem] {
        var items: [SafetyActivityItem] = []
        if checklist.contains(where: { $0.id == "lights" && $0.status == .due }) {
            items.append(SafetyActivityItem(
                id: "lights-pending",
                title: "Lights check pending",
                subtitle: "Today",
                isWarning: true
            ))
        }
        if checklist.contains(where: { $0.status == .complete }) {
            items.append(SafetyActivityItem(
                id: "pretrip-done",
                title: "Pre-trip check completed",
                subtitle: "Today 09:12",
                isWarning: false
            ))
        }
        return items
    }

    static func oldestTyreDescription(records: [TyreRecord]) -> String {
        guard let record = records.first else { return "Not set up" }
        return record.ageText
    }

    static func dimensionDisplay(_ metres: Double) -> String {
        metres > 0 ? Formatters.metres(metres) : "Not set"
    }

    static func maxWeightLabel(for kind: VehicleKind) -> String {
        kind == .caravan ? "MTPLM" : "MAM"
    }

    static func unladenWeightLabel(for kind: VehicleKind) -> String {
        kind == .caravan ? "Unladen (MIRO)" : "Unladen (MRO)"
    }

    static func vehicleKindName(for kind: VehicleKind) -> String {
        kind.displayName.lowercased()
    }
}
