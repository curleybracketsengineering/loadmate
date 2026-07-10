import SwiftUI
import UIKit

/// Chooses between phone and iPad presentation. iPhone UI stays on compact phone idiom only.
enum AppLayout {
    /// Portrait width of 11″ iPad class devices (Air / Pro 11″, 10.9″ iPad).
    static let iPad11ReferenceWidth: CGFloat = 820

    /// Minimum container width to use iPad layouts (matches 11″ portrait short side).
    static let padLayoutMinimumWidth: CGFloat = iPad11ReferenceWidth

    /// Fallback before layout geometry is measured (full-screen iPad).
    static var defaultUsePadLayout: Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        let bounds = UIScreen.main.bounds
        return max(bounds.width, bounds.height) >= padLayoutMinimumWidth
    }

    static func usePadLayout(availableWidth: CGFloat) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        return availableWidth >= padLayoutMinimumWidth
    }
}

private struct UsePadLayoutKey: EnvironmentKey {
    static let defaultValue: Bool = AppLayout.defaultUsePadLayout
}

extension EnvironmentValues {
    var usePadLayout: Bool {
        get { self[UsePadLayoutKey.self] }
        set { self[UsePadLayoutKey.self] = newValue }
    }
}

private struct PadTopTabBarActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when iPad root uses the floating top pill tab bar (hide per-tab nav chrome).
    var padTopTabBarActive: Bool {
        get { self[PadTopTabBarActiveKey.self] }
        set { self[PadTopTabBarActiveKey.self] = newValue }
    }
}

/// Max widths and gutters tuned for 11″ iPad; scales down on narrower containers.
enum PadContentLayout {
    /// Single-column forms (Settings, etc.).
    static let settingsMaxWidth: CGFloat = 640
    static let readableMaxWidth: CGFloat = 680
    /// Combined load + placement workspace (fits 11″ landscape with gutters).
    static let workspaceMaxWidth: CGFloat = 960
    /// Cutaway illustration and zone chips.
    static let cutawayMaxWidth: CGFloat = 700
    static let loadColumnWidth: CGFloat = 340
    static let horizontalGutter: CGFloat = 24

    /// Floating pill tab bar — compact on 13″, nearly full width on 11″.
    static let tabBarOuterHorizontalPadding: CGFloat = 14
    static let tabBarTopPadding: CGFloat = 8.5
    static let tabBarBottomPadding: CGFloat = 7
    static let tabBarPillInnerPadding: CGFloat = 5
    static let tabBarPillVerticalPadding: CGFloat = 5
    static let tabBarItemSpacing: CGFloat = 3.5
    static let tabBarItemHorizontalPadding: CGFloat = 10
    static let tabBarItemVerticalPadding: CGFloat = 8.5
    static let tabBarIconSize: CGFloat = 19
    static let tabBarShadowRadius: CGFloat = 8.5
    static let tabBarShadowYOffset: CGFloat = 2.5
    /// 13″ iPad landscape width and wider — keep the compact centred pill.
    static let tabBarCompactPillThreshold: CGFloat = 1_280
    static let tabBarCompactPillMaxWidth: CGFloat = 780
    /// Horizontal scale applied to the pill width (0.85 = 15% narrower).
    static let tabBarPillWidthScale: CGFloat = 0.85

    static func tabBarPillWidth(for availableWidth: CGFloat) -> CGFloat {
        let margins = tabBarOuterHorizontalPadding * 2
        let baseWidth: CGFloat
        if availableWidth >= tabBarCompactPillThreshold {
            baseWidth = min(tabBarCompactPillMaxWidth, availableWidth - margins)
        } else {
            baseWidth = availableWidth - margins
        }
        return baseWidth * tabBarPillWidthScale
    }

    static func tabBarFont(for availableWidth: CGFloat) -> Font {
        let size: CGFloat = availableWidth >= tabBarCompactPillThreshold ? 13 : 14
        return .system(size: size)
    }
}

private struct PadReadableContentModifier: ViewModifier {
    @Environment(\.usePadLayout) private var usePadLayout
    var maxWidth: CGFloat = PadContentLayout.readableMaxWidth

    func body(content: Content) -> some View {
        if usePadLayout {
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

extension View {
    /// Visible scrollbar and keyboard dismiss for Load Planner tab panels on iPad.
    func loadPlannerScrollPanel() -> some View {
        scrollIndicators(.visible, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
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
