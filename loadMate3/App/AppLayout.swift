import SwiftUI
import UIKit

/// Chooses between phone and iPad presentation. iPhone UI stays on compact phone idiom only.
enum AppLayout {
    static var usePadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

/// Max widths and gutters so iPad screens do not stretch edge-to-edge.
enum PadContentLayout {
    /// Single-column forms (Settings, etc.).
    static let settingsMaxWidth: CGFloat = 640
    static let readableMaxWidth: CGFloat = 720
    /// Combined load + placement workspace.
    static let workspaceMaxWidth: CGFloat = 1_120
    /// Cutaway illustration and zone chips.
    static let cutawayMaxWidth: CGFloat = 820
    static let loadColumnWidth: CGFloat = 400
    static let horizontalGutter: CGFloat = 40
}

private struct PadReadableContentModifier: ViewModifier {
    var maxWidth: CGFloat = PadContentLayout.readableMaxWidth

    func body(content: Content) -> some View {
        if AppLayout.usePadLayout {
            content
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, PadContentLayout.horizontalGutter)
        } else {
            content
        }
    }
}

extension View {
    /// Centers content on iPad with side margins; no-op on iPhone.
    func padReadableContent(maxWidth: CGFloat = PadContentLayout.readableMaxWidth) -> some View {
        modifier(PadReadableContentModifier(maxWidth: maxWidth))
    }
}

extension LoadZone {
    /// Short label on iPad zone chips (motorhome garage shown as “Boot” per mockup).
    func padChipTitle(for kind: VehicleKind) -> String {
        if kind == .motorhome, self == .garage { return "Boot" }
        if kind == .motorhome, self == .bikeRack { return "Bike" }
        return locationBadgeTitle(for: kind)
    }
}
