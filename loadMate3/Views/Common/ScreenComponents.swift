import SwiftUI
import UIKit

/// Shared layout metrics for scroll-based screens (matches inset spacing from design mocks).
enum AppScreenMetrics {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let fieldSpacing: CGFloat = 20
    static let cornerRadius: CGFloat = 12
    static let inputMinHeight: CGFloat = 48
    static let heroIconSize: CGFloat = 56
}

/// Standard screen background: primary surface with optional subtle grouping.
struct AppScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.backgroundPrimary)
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }
}

// MARK: - Hero

struct AppHeroSection: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: AppScreenMetrics.heroIconSize * 0.55, weight: .regular))
                .foregroundStyle(AppColors.blue)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}

// MARK: - Section chrome

struct AppSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.separator.opacity(0.35))
            .frame(height: 1)
    }
}

struct AppWarningBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(AppColors.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.warningBannerText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
        .padding(.vertical, 12)
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
                .background(AppColors.blue)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
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
            .foregroundStyle(AppColors.blue)
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
            .foregroundStyle(AppColors.textPrimary)
            .focused($focused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: AppScreenMetrics.inputMinHeight, alignment: .center)
            .background(AppColors.inputSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(focused ? AppColors.blue.opacity(0.55) : AppColors.inputBorder, lineWidth: focused ? 2 : 1)
            }
            .animation(.easeInOut(duration: 0.2), value: focused)
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AppBoundedTextField(placeholder: placeholder, text: $text, keyboard: keyboard)
        }
    }
}

/// Bordered numeric input (shared by labeled fields and accent-style factor rows).
struct AppBoundedNumberField: View {
    @Binding var value: Double
    var fractionDigitsUpperBound: Int

    @FocusState private var focused: Bool

    var body: some View {
        TextField(
            "",
            value: $value,
            format: .number.precision(.fractionLength(0...fractionDigitsUpperBound))
        )
        .keyboardType(.decimalPad)
        .font(.body.weight(.semibold))
        .foregroundStyle(AppColors.textPrimary)
        .multilineTextAlignment(.leading)
        .focused($focused)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: AppScreenMetrics.inputMinHeight, alignment: .center)
        .background(AppColors.inputSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous)
                .strokeBorder(focused ? AppColors.blue.opacity(0.55) : AppColors.inputBorder, lineWidth: focused ? 2 : 1)
        }
        .animation(.easeInOut(duration: 0.2), value: focused)
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
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
        VStack(alignment: .leading, spacing: 10) {
            AppAccentLabel(text: accentTitle)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AppBoundedNumberField(value: $value, fractionDigitsUpperBound: 2)
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
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.blue)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
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
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - List / card rows

/// Wraps list-style content in an inset grouped–like card on the page background.
struct AppGroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppScreenMetrics.horizontalPadding)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppScreenMetrics.cornerRadius, style: .continuous))
    }
}
