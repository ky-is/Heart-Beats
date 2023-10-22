import SwiftUI

struct CreateCombineGrouping: View {
	let type: String

	@State private var fromGrouping = ""
	@State private var intoGrouping = ""

	@EnvironmentObject private var syncStorage: SyncStorage
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		let isGenre = type == "genre"
		let baseEntries = (isGenre ? MediaCollection.genres : MediaCollection.artists).entries
		List {
			Section("Into \(type):") {
				Picker("Combine Into", selection: $intoGrouping) {
					Text("")
					ForEach(baseEntries.filter { $0.id != fromGrouping }) {
						Text($0.id)
					}
				}
			}
			Section("Combine from \(type):") {
				Picker("Combine From", selection: $fromGrouping) {
					Text("")
					ForEach(baseEntries.filter { $0.id != intoGrouping }) {
						Text($0.id)
					}
				}
			}
		}
			.pickerStyle(.wheel)
			.navigationTitle("Combine \(type.capitalized)s")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Save") {
						var combined = isGenre ? syncStorage.combinedGenres : syncStorage.combined
						combined.append([intoGrouping, fromGrouping])
						withAnimation {
							if isGenre {
								syncStorage.combinedGenres = combined
							} else {
								syncStorage.combined = combined
							}
						}
						dismiss()
					}
						.disabled(fromGrouping == "" || intoGrouping == "" || fromGrouping == intoGrouping)
				}
			}
	}
}

#Preview {
	NavigationStack {
		CreateCombineGrouping(type: "artist")
	}
		.tint(.accent)
		.environmentObject(SyncStorage.shared)
}
