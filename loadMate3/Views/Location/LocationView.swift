import SwiftUI
import SwiftData

struct LocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var loadedItems: [LoadedItem]
    @StateObject private var viewModel = LocationViewModel()

    var body: some View {
        NavigationStack {
            List {
                if loadedItems.isEmpty {
                    Text("No loaded items yet. Use the Load tab first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(loadedItems) { loaded in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loaded.item?.name ?? "Unknown Item")
                                .font(.headline)
                            Text("Qty: \(loaded.quantity) - \(Formatters.kg((loaded.item?.weightKg ?? 0) * Double(loaded.quantity)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("Zone", selection: Binding(
                                get: { loaded.zone },
                                set: { newZone in
                                    viewModel.updateZone(for: loaded, to: newZone, in: modelContext)
                                }
                            )) {
                                ForEach(LoadZone.allCases) { zone in
                                    Text(zone.title).tag(zone)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
            .navigationTitle("Location")
        }
    }
}
