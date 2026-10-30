import SwiftUI

struct CreateCombineGrouping: View {
	let type: String

	@State private var fromGrouping = ""
	@State private var intoGrouping = ""

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		let isGenre = type == "genre"
		let names = (isGenre ? GroupedCollection.genres : GroupedCollection.artists).entries.map(\.id)
		List {
			Section {
				GroupingChooser(title: "Combine Into", type: type, names: names.filter { $0 != fromGrouping }, selection: $intoGrouping)
			} header: {
				SectionTitle("Into \(type):")
			}
			Section {
				GroupingChooser(title: "Combine From", type: type, names: names.filter { $0 != intoGrouping }, selection: $fromGrouping)
			} header: {
				SectionTitle("Combine from \(type):")
			}
		}
			.navigationTitle("Combine \(type.capitalized)s")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Save") {
						// The sync observer rescans the collection after this write
						UserDefaults.standard.setCombined(UserDefaults.standard.combined(for: type) + [[intoGrouping, fromGrouping]], for: type)
						dismiss()
					}
						.disabled(fromGrouping == "" || intoGrouping == "" || fromGrouping == intoGrouping)
				}
			}
	}
}

/// A row showing the chosen name, opening a searchable list of every name. Easier than a wheel through the whole library, with VoiceOver, Switch Control and large text too.
private struct GroupingChooser: View {
	let title: String
	let type: String
	let names: [String]
	@Binding var selection: String

	var body: some View {
		NavigationLink {
			GroupingChoices(title: title, type: type, names: names, selection: $selection)
		} label: {
			LabeledContent(title, value: selection.isEmpty ? "None" : selection)
		}
	}
}

private struct GroupingChoices: View {
	let title: String
	let type: String
	let names: [String]
	@Binding var selection: String

	@State private var search = ""

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		let shown = search.isEmpty ? names : names.filter { $0.localizedStandardContains(search) }
		List(shown, id: \.self) { name in
			Button {
				selection = name
				dismiss()
			} label: {
				HStack {
					Text(name)
						.foregroundStyle(.primary)
					Spacer()
					if name == selection {
						Image(systemName: "checkmark")
							.foregroundStyle(.tint)
							.accessibilityHidden(true)
					}
				}
			}
				.accessibilityAddTraits(name == selection ? .isSelected : [])
		}
			.overlay {
				if shown.isEmpty {
					ContentUnavailableView.search(text: search)
				}
			}
			.searchable(text: $search, prompt: "Search \(type)s")
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		CreateCombineGrouping(type: "artist")
	}
}
