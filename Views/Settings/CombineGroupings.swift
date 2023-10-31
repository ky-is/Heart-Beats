import SwiftUI

struct CombineGroupings: View {
	let type: String

	@AppStorage(UserDefaults.Key.combined) private var combinedArtists = UserDefaults.standard.combined
	@AppStorage(UserDefaults.Key.combinedGenres) private var combinedGenres = UserDefaults.standard.combinedGenres

	var body: some View {
		let isGenre = type == "genre"
		List {
			var baseCombined = isGenre ? combinedGenres : combinedArtists
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
//								if isGenre {
//									combinedGenres = baseCombined
//								} else {
//									combinedArtists = baseCombined
//								}
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
}
