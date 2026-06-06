import SwiftUI

/// Floating pill tab bar matching the system iPad style; widens on 11″ so every tab fits.
struct PadTabBar: View {
    @Binding var selection: AppTab
    let availableWidth: CGFloat

    private struct TabDescriptor: Identifiable {
        let tab: AppTab
        let title: String
        let systemImage: String
        var id: AppTab { tab }
    }

    private var tabs: [TabDescriptor] {
        [
            TabDescriptor(tab: .weight, title: "Summary", systemImage: "plus.forwardslash.minus"),
            TabDescriptor(tab: .load, title: "Load & placement", systemImage: "shippingbox"),
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
                    .fill(Color(.systemBackground))
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
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PadContentLayout.tabBarItemHorizontalPadding)
            .padding(.vertical, PadContentLayout.tabBarItemVerticalPadding)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(tab.title)
    }
}
