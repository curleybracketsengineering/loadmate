import SwiftUI
import SwiftData

struct DisclaimerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DisclaimerViewModel()

    let appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Safety Disclaimer")
                        .font(.largeTitle.bold())
                    Text("This app is an estimation tool only.")
                    Text("Always physically measure nose weight and verify total caravan weight.")
                    Text("Do not exceed MTPLM, tow-ball limits, or vehicle limits.")
                    Text("By continuing, you accept that estimates may be incorrect.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button("I Understand and Accept") {
                    viewModel.acceptDisclaimer(appState: appState, in: modelContext)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }
}
