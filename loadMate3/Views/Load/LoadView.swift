import SwiftUI
import SwiftData

struct LoadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LibraryItem.name)]) private var libraryItems: [LibraryItem]
    @Query private var loadedItems: [LoadedItem]

    @StateObject private var viewModel = LoadViewModel()
    @State private var newName = ""
    @State private var newWeight = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Add Library Item") {
                    TextField("Item name", text: $newName)
                    TextField("Weight (kg)", text: $newWeight)
                        .keyboardType(.decimalPad)
                    Button("Add Item") {
                        guard let weight = Double(newWeight), weight > 0, !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }
                        viewModel.addLibraryItem(name: newName, weightKg: weight, in: modelContext)
                        newName = ""
                        newWeight = ""
                    }
                }

                Section("Library") {
                    if libraryItems.isEmpty {
                        Text("No items yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(libraryItems) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(Formatters.kg(item.weightKg))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("x\(quantity(for: item))")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Load") {
                                    viewModel.load(item: item, loadedItems: loadedItems, in: modelContext)
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Unload") {
                                    viewModel.unload(item: item, loadedItems: loadedItems, in: modelContext)
                                }
                                .tint(.orange)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.delete(item: libraryItems[index], loadedItems: loadedItems, in: modelContext)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load")
        }
    }

    private func quantity(for item: LibraryItem) -> Int {
        loadedItems.first(where: { $0.item?.id == item.id })?.quantity ?? 0
    }
}
