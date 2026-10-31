import SwiftUI

struct EmptyMediaList: View {
	var collection: GroupedCollection
	let listViewMode: String
	let imageWidth: CGFloat

	private let play: (MediaEntry, Bool) -> Void = { _, _ in }

	var body: some View {
		if !collection.hasLoaded {
			Group {
				if listViewMode == "grid" {
					LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))]) {
						ForEach(MediaEntry.screenshotData) {
							MediaListEntry(groupBy: nil, listViewMode: listViewMode, largeTitles: false, entry: $0, imageWidth: imageWidth, inFavorites: false, play: play)
						}
					}
				} else {
					List {
						ForEach(MediaEntry.screenshotData) {
							MediaListEntry(groupBy: nil, listViewMode: listViewMode, largeTitles: false, entry: $0, imageWidth: imageWidth, inFavorites: false, play: play)
						}
					}
					.listStyle(.plain)
				}
			}
				.redacted(reason: .placeholder)
				// The placeholder rows are sample names, so VoiceOver hears that it's loading instead
				.accessibilityRepresentation {
					Text("Loading your library…")
				}
				.navigationTitle("… \(collection.groupBy.capitalized)s")
		} else {
			ScrollView {
				GettingStartedCard(state: collection.gettingStartedState)
					.padding()
			}
		}
	}
}

#Preview {
	NavigationStack {
		EmptyMediaList(collection: GroupedCollection(groupBy: "artist"), listViewMode: "grid", imageWidth: 128)
	}
		.fontDesign(.rounded)
}
