import SwiftUI

enum PadTab: Hashable {
    case summary
    case load
    case safety
    case maintenance
    case checklist
    case settings
}

/// Floating pill tab bar at the top of the iPad workspace.
struct PadTabBar: View {
    @Binding var selection: PadTab
    let availableWidth: CGFloat

    private struct TabDescriptor: Identifiable {
        let tab: PadTab
        let title: String
        let systemImage: String
        var id: PadTab { tab }
    }

    private var tabs: [TabDescriptor] {
        [
            TabDescriptor(tab: .summary, title: "Summary", systemImage: "plus.forwardslash.minus"),
            TabDescriptor(tab: .load, title: "Load & placement", systemImage: "shippingbox"),
            TabDescriptor(tab: .safety, title: "Safety", systemImage: "shield"),
            TabDescriptor(tab: .maintenance, title: "Maintenance", systemImage: "wrench.and.screwdriver"),
            TabDescriptor(tab: .checklist, title: "Checklist", systemImage: "checklist"),
            TabDescriptor(tab: .settings, title: "Settings", systemImage: "gearshape"),
        ]
    }

    private var pillWidth: CGFloat {
        PadContentLayout.tabBarPillWidth(for: availableWidth)
    }

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: PadContentLayout.tabBarItemSpacing) {
                ForEach(tabs) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, PadContentLayout.tabBarPillInnerPadding)
            .padding(.vertical, PadContentLayout.tabBarPillVerticalPadding)
            .frame(width: pillWidth)
            .background {
                Capsule(style: .continuous)
                    .fill(LyneqoTheme.card)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: PadContentLayout.tabBarShadowRadius,
                        y: PadContentLayout.tabBarShadowYOffset
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PadContentLayout.tabBarOuterHorizontalPadding)
        .padding(.top, PadContentLayout.tabBarTopPadding)
        .padding(.bottom, PadContentLayout.tabBarBottomPadding)
        .background(LyneqoTheme.background)
    }

    private func tabButton(_ tab: TabDescriptor) -> some View {
        let isSelected = selection == tab.tab

        return Button {
            selection = tab.tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14.5, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: PadContentLayout.tabBarIconSize, height: PadContentLayout.tabBarIconSize)

                Text(tab.title)
                    .font(PadContentLayout.tabBarFont(for: availableWidth))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? LyneqoTheme.primaryTeal : LyneqoTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PadContentLayout.tabBarItemHorizontalPadding)
            .padding(.vertical, PadContentLayout.tabBarItemVerticalPadding)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(LyneqoTheme.softTeal)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(tab.title)
    }
}
