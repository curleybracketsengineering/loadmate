import SwiftUI

enum ChecklistProgress {
    static func items(in section: ChecklistSection) -> [ChecklistItem] {
        let grouped = section.groups.flatMap(\.items)
        let legacy = section.items.filter { $0.group == nil }
        return (grouped + legacy).sorted { $0.sortOrder < $1.sortOrder }
    }

    static func counts(in section: ChecklistSection) -> (completed: Int, total: Int) {
        let items = items(in: section)
        return (items.filter(\.isChecked).count, items.count)
    }

    static func counts(in group: ChecklistGroup) -> (completed: Int, total: Int) {
        let items = group.items.sorted { $0.sortOrder < $1.sortOrder }
        return (items.filter(\.isChecked).count, items.count)
    }

    static func overall(in sections: [ChecklistSection]) -> (completed: Int, total: Int) {
        sections.reduce(into: (0, 0)) { result, section in
            let counts = counts(in: section)
            result.0 += counts.completed
            result.1 += counts.total
        }
    }

    static func fraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    static func percent(completed: Int, total: Int) -> Int {
        Int((fraction(completed: completed, total: total) * 100).rounded())
    }
}

enum ChecklistPresentation {
    struct SectionStyle {
        let systemImage: String
        let tint: Color
        let summary: String?
    }

    static func sectionStyle(for title: String) -> SectionStyle {
        switch title {
        case "Before leaving home":
            return SectionStyle(
                systemImage: "house.fill",
                tint: AppColors.green,
                summary: "Final checks before you set off."
            )
        case "Towing setup":
            return SectionStyle(
                systemImage: "truck.box.fill",
                tint: AppColors.blue,
                summary: "Couple up and verify lights and safety."
            )
        case "Pitching":
            return SectionStyle(
                systemImage: "tent.fill",
                tint: AppColors.blue,
                summary: "Ensure a safe, level and comfortable setup."
            )
        case "Departure":
            return SectionStyle(
                systemImage: "caravan.fill",
                tint: AppColors.purple,
                summary: "Break camp and prepare to leave."
            )
        case "EU / Overseas travel checklist":
            return SectionStyle(
                systemImage: "globe.europe.africa.fill",
                tint: AppColors.orange,
                summary: "Documents and kit for travel abroad."
            )
        default:
            return SectionStyle(systemImage: "checklist", tint: AppColors.blue, summary: nil)
        }
    }

    static func groupStyle(for title: String) -> (systemImage: String, summary: String?) {
        switch title {
        case "On site":
            return ("mappin.and.ellipse", "Position and secure the unit on the pitch.")
        case "Services":
            return ("drop.fill", "Connect utilities safely.")
        case "Stability":
            return ("shield.lefthalf.filled", "Stabilise before opening up.")
        case "Water & waste":
            return ("drop.fill", "Tanks and valves ready for travel.")
        case "Interior":
            return ("sofa.fill", "Cabinet and loose-item checks.")
        case "Gas & electric":
            return ("bolt.fill", "Power and gas settings for travel.")
        case "Exterior & chassis":
            return ("wrench.and.screwdriver.fill", "Outside hardware secured.")
        case "Hitch & safety":
            return ("link", "Coupling and safety cable checks.")
        case "Moving off checks":
            return ("light.beacon.max.fill", "Lights and mirrors before departure.")
        case "Exterior & hitch":
            return ("car.rear.and.tire.marks", "Outside checks before leaving site.")
        case "Final checks":
            return ("checkmark.shield.fill", "Last walk-around before moving off.")
        case "Legal requirements":
            return ("doc.text.fill", "Documents and mandatory kit.")
        case "Vehicle compliance":
            return ("car.fill", "Insurance and registration abroad.")
        case "Navigation & payments":
            return ("map.fill", "Apps, maps, and money.")
        case "Ferry / tunnel":
            return ("ferry.fill", "Crossing preparation.")
        default:
            return ("folder.fill", nil)
        }
    }
}

struct ChecklistProgressRing: View {
    let completed: Int
    let total: Int

    private var fraction: Double {
        ChecklistProgress.fraction(completed: completed, total: total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(AppColors.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed) of \(total)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .padding(6)
        }
        .frame(width: 76, height: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) complete")
    }
}

struct ChecklistLinearProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                Capsule(style: .continuous)
                    .fill(AppColors.blue)
                    .frame(width: max(0, proxy.size.width * fraction))
            }
        }
        .frame(height: 6)
    }
}

struct ChecklistIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.12))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
