import SwiftUI

struct CombineGroupings: View {
	let type: String

	@EnvironmentObject private var syncStorage: SyncStorage

	var body: some View {
		let isGenre = type == "genre"
		List {
			var baseCombined = isGenre ? syncStorage.combinedGenres : syncStorage.combined
			Section("Existing combinations:") {
				if baseCombined.isEmpty {
					Text("No entries")
						.foregroundStyle(.secondary)
				} else {
					ForEach(baseCombined, id: \.self) { combineEntries in
						if combineEntries.count == 2 {
							Text("\(combineEntries[0])")
							+
							Text(" ← \(combineEntries[1])")
								.foregroundStyle(.secondary)
						}
					}
						.onDelete { offsets in
							baseCombined.remove(atOffsets: offsets)
							withAnimation {
								if isGenre {
									syncStorage.combinedGenres = baseCombined
								} else {
									syncStorage.combined = baseCombined
								}
							}
						}
				}
			}
			Section {
				NavigationLink("Create new") {
					CreateCombineGrouping(type: type)
				}
					.foregroundStyle(.accent)
			}
		}
			.pickerStyle(.wheel)
			.navigationTitle("Combine \(type.capitalized)s")
	}
}

#Preview {
	NavigationStack {
		CombineGroupings(type: "artist")
	}
		.tint(.accent)
		.environmentObject(SyncStorage.shared)
}
