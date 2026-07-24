import SwiftUI

public enum LyneqoTheme {
    public static let background = Color("LyneqoBackground")
    public static let card = Color("LyneqoCard")
    public static let primaryText = Color("LyneqoPrimaryText")
    public static let secondaryText = Color("LyneqoSecondaryText")
    public static let primaryTeal = Color("LyneqoPrimaryTeal")
    public static let aqua = Color("LyneqoAqua")
    public static let softTeal = Color("LyneqoSoftTeal")
    public static let deepNavy = Color("LyneqoDeepNavy")
    public static let border = Color("LyneqoBorder")
    public static let disabled = Color("LyneqoDisabled")

    public enum Status {
        public static let success = Color("StatusSuccess")
        public static let warning = Color("StatusWarning")
        public static let danger = Color("StatusDanger")
        public static let info = Color("StatusInfo")
    }

    public enum Product {
        public static let caravan = Color("CaravanAccent")
        public static let motorhome = Color("MotorhomeAccent")
        public static let tub = Color("TubAccent")
        public static let budget = Color("BudgetAccent")
        public static let learn = Color("LearnAccent")
    }
}

public extension View {
    func lyneqoCard() -> some View {
        self
            .padding(16)
            .background(LyneqoTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LyneqoTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}
