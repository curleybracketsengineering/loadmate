import SwiftUI
import UIKit

// MARK: - Design system (spacing, radii, motion)

/// Layout and chrome tokens aligned to an 8-point grid and iOS grouped-card patterns.
enum AppScreenMetrics {
    static let horizontalPadding: CGFloat = 20
    static let verticalScreenPadding: CGFloat = 16
    static let bottomScrollPadding: CGFloat = 24

    /// Between major sections (24–32 on the scale).
    static let sectionSpacing: CGFloat = 24
    static let sectionSpacingLoose: CGFloat = 32

    /// Between labeled controls (12–16).
    static let fieldSpacing: CGFloat = 16
    static let controlSpacing: CGFloat = 12
    static let smallSpacing: CGFloat = 8
    static let tinySpacing: CGFloat = 4

    /// Standard rounded rect (screens, rows).
    static let cornerRadius: CGFloat = 16
    /// Inputs and compact controls.
    static let fieldCornerRadius: CGFloat = 14
    /// Large feature cards.
    static let cardCornerRadiusLarge: CGFloat = 20

    static let cardInteriorPadding: CGFloat = 16

    static let inputMinHeight: CGFloat = 50
    static let heroIconSize: CGFloat = 56
}

/// Standard screen background: system grouped surface.
struct AppScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemGroupedBackground))
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }
}

/// Inline navigation bar title centered in the bar, bold title text (matches Checklist tab styling).
private struct AppPrincipalTabTitleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
    }
}

extension View {
    /// Tab root title: same position and typography as the Checklist screen.
    func appPrincipalTabTitle(_ title: String) -> some View {
        modifier(AppPrincipalTabTitleModifier(title: title))
    }
}

// MARK: - Hero

struct AppHeroSection: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: AppScreenMetrics.heroIconSize * 0.55, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppScreenMetrics.smallSpacing)
    }
}

// MARK: - Section chrome

struct AppSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.35))
            .frame(height: 1)
    }
}

struct AppWarningBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: AppScreenMetrics.controlSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(Color.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.warningBannerText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
        .padding(.vertical, AppScreenMetrics.fieldSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.warningBannerBackground)
    }
}

/// Circular primary FAB (+), positioned above the tab bar / safe area.
struct AppFloatingAddButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AppSectionHeading: View {
    let title: String
    let caption: String?

    init(_ title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSupporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Accent label for sub-items (single accent color — avoids rainbow section titles).
struct AppAccentLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }
}

// MARK: - Search

/// Compact iOS-style search field (magnifying glass, tertiary fill, clear button).
struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String = "Search", text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack(spacing: AppScreenMetrics.smallSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSupporting)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundStyle(Color.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppColors.textSupporting)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppScreenMetrics.controlSpacing)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search")
    }
}

// MARK: - Numeric fields

/// Single-line text input matching bordered numeric fields (Load tab, etc.).
struct AppBoundedTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled()
            .font(.body.weight(.medium))
            .foregroundStyle(Color.primary)
            .focused($focused)
            .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .frame(minHeight: AppScreenMetrics.inputMinHeight, alignment: .center)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                    .strokeBorder(focused ? Color.accentColor.opacity(0.55) : Color(.separator), lineWidth: focused ? 2 : 1)
            }
            .animation(.spring(response: 0.35), value: focused)
    }
}

struct AppLabeledTextField: View {
    let title: String
    let caption: String?
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    init(
        _ title: String,
        caption: String? = nil,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) {
        self.title = title
        self.caption = caption
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AppBoundedTextField(placeholder: placeholder, text: $text, keyboard: keyboard)
        }
    }
}

/// Bordered numeric input (shared by labeled fields and accent-style factor rows).
///
/// Uses a string draft while editing so the field can be fully cleared; `TextField(value:format:)`
/// with `Double` snaps back because an empty string is not a stable `Double` state.
struct AppBoundedNumberField: View {
    @Binding var value: Double
    var fractionDigitsUpperBound: Int
    /// Zone factors can be negative; caravan weights are unsigned.
    var allowsSigned: Bool = false

    @FocusState private var focused: Bool
    @State private var text: String = ""

    private var integerWeightsOnly: Bool { fractionDigitsUpperBound == 0 }

    private var keyboard: UIKeyboardType {
        if allowsSigned { return .numbersAndPunctuation }
        return integerWeightsOnly ? .numberPad : .decimalPad
    }

    private func formatForDisplay(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...fractionDigitsUpperBound)))
    }

    private func compactNumericString(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sync bound value while the user is editing (allows empty text → 0 for unset weights).
    private func applyTextToValue() {
        let compact = compactNumericString(text)
        if compact.isEmpty {
            value = 0
            return
        }
        if compact == "-" || compact == "." || compact == "-." {
            return
        }
        guard let parsed = Double(compact) else { return }
        if integerWeightsOnly {
            value = parsed.rounded(.toNearestOrAwayFromZero)
        } else {
            value = parsed
        }
    }

    /// Normalize display when focus ends.
    private func commitEditing() {
        let compact = compactNumericString(text)
        if compact.isEmpty || compact == "-" || compact == "." || compact == "-." {
            value = 0
            text = formatForDisplay(0)
            return
        }
        guard let parsed = Double(compact) else {
            text = formatForDisplay(value)
            return
        }
        let finalValue: Double
        if integerWeightsOnly {
            finalValue = parsed.rounded(.toNearestOrAwayFromZero)
        } else {
            finalValue = parsed
        }
        value = finalValue
        text = formatForDisplay(finalValue)
    }

    var body: some View {
        TextField("", text: $text)
            .keyboardType(keyboard)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.primary)
            .multilineTextAlignment(.leading)
            .focused($focused)
            .padding(.horizontal, AppScreenMetrics.cardInteriorPadding)
            .padding(.vertical, AppScreenMetrics.fieldSpacing)
            .frame(minHeight: AppScreenMetrics.inputMinHeight, alignment: .center)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.fieldCornerRadius, style: .continuous)
                    .strokeBorder(focused ? Color.accentColor.opacity(0.55) : Color(.separator), lineWidth: focused ? 2 : 1)
            }
            .animation(.spring(response: 0.35), value: focused)
            .onAppear {
                text = formatForDisplay(value)
            }
            .onChange(of: value) { _, newValue in
                guard !focused else { return }
                text = formatForDisplay(newValue)
            }
            .onChange(of: text) { _, _ in
                guard focused else { return }
                applyTextToValue()
            }
            .onChange(of: focused) { wasFocused, isFocused in
                if wasFocused && !isFocused {
                    commitEditing()
                }
            }
    }
}

struct AppLabeledNumberField: View {
    let title: String
    let caption: String?
    @Binding var value: Double
    var fractionDigitsUpperBound: Int

    init(
        _ title: String,
        caption: String? = nil,
        value: Binding<Double>,
        fractionDigitsUpperBound: Int = 2
    ) {
        self.title = title
        self.caption = caption
        self._value = value
        self.fractionDigitsUpperBound = fractionDigitsUpperBound
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSupporting)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AppBoundedNumberField(value: $value, fractionDigitsUpperBound: fractionDigitsUpperBound)
        }
    }
}

/// Factor row: single accent color for the zone name (avoids per-zone rainbow titles).
struct AppFactorField: View {
    let accentTitle: String
    let caption: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            AppAccentLabel(text: accentTitle)
            Text(caption)
                .font(.caption)
                .foregroundStyle(AppColors.textSupporting)
                .fixedSize(horizontal: false, vertical: true)
            AppBoundedNumberField(value: $value, fractionDigitsUpperBound: 2, allowsSigned: true)
        }
    }
}

// MARK: - Buttons

struct AppPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppScreenMetrics.smallSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppScreenMetrics.inputMinHeight)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

struct AppSecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

// MARK: - Grouped cards

/// Wraps content in an inset grouped–style card on the page background.
struct AppGroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppScreenMetrics.cardInteriorPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.45), lineWidth: 1)
            }
    }
}

/// Settings-style section: heading above a bordered grouped card.
struct AppSettingsSection<Content: View>: View {
    let title: String
    let caption: String?
    @ViewBuilder let content: Content

    init(
        _ title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            AppSectionHeading(title, caption: caption)
            AppGroupedCard {
                content
            }
        }
    }
}

/// Collapsible advanced settings block — collapsed by default.
struct AppCollapsibleSettingsSection<Content: View>: View {
    let title: String
    let caption: String?
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    init(
        _ title: String,
        caption: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.caption = caption
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppScreenMetrics.controlSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: AppScreenMetrics.controlSpacing) {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.tinySpacing) {
                        HStack(spacing: AppScreenMetrics.smallSpacing) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                            Text("Advanced")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                        if let caption, !caption.isEmpty, !isExpanded {
                            Text(caption)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: AppScreenMetrics.smallSpacing)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Double tap to show or hide \(title)")

            if isExpanded {
                AppGroupedCard {
                    VStack(alignment: .leading, spacing: AppScreenMetrics.fieldSpacing) {
                        if let caption, !caption.isEmpty {
                            Text(caption)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSupporting)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        content
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
