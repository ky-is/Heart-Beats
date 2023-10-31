import SwiftUI

struct CreateCombineGrouping: View {
	let type: String

	@State private var fromGrouping = ""
	@State private var intoGrouping = ""

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
						withAnimation {
							UserDefaults.standard.currentCombined.append([intoGrouping, fromGrouping])
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
}
