import SwiftUI

struct EmptyMediaList: View {
	var collection: MediaCollection
	let listViewMode: String
	let imageWidth: CGFloat

	private let play: (MediaEntry, Bool) -> Void = { _, _ in }

	var body: some View {
		if (collection.groupBy == "genre" ? UserDefaults.standard.cachedGenres : UserDefaults.standard.cachedArtists) == nil {
			Group {
				if listViewMode == "grid" {
					LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))]) {
						ForEach(MediaCollection.screenshotData) {
							MediaListEntry(listViewMode: listViewMode, entry: $0, imageWidth: imageWidth, inFavorites: false, play: play)
						}
					}
				} else {
					List {
						ForEach(MediaCollection.screenshotData) {
							MediaListEntry(listViewMode: listViewMode, entry: $0, imageWidth: imageWidth, inFavorites: false, play: play)
						}
					}
					.listStyle(.plain)
				}
			}
				.redacted(reason: .placeholder)
				.navigationTitle("… \(collection.groupBy.capitalized)s")
		} else {
			List {
				Section {} footer: {
					Text("No 5-star songs found in your library…")
						.font(.title)
						.multilineTextAlignment(.center)
						.padding(.top)
						.padding(.horizontal)
				}

				Section("Step 1: Ensure star ratings are enabled") {
					Link(destination: URL(string: "App-prefs:MUSIC")!) {
						Label("Settings > Music >\nEnable \"Show Star Ratings\"", systemImage: "gear.circle.fill")
					}
				}
				Section("Step 2: Rate songs in Music app") {
					Link(destination: URL(string: "audio-player-event:")!) {
						Label("Open Music App to rate", systemImage: "music.note.house.fill")
					}
				}
			}
		}
	}
}

#Preview {
	NavigationStack {
		EmptyMediaList(collection: MediaCollection(groupBy: "artist"), listViewMode: "grid", imageWidth: 128)
	}
		.fontDesign(.rounded)
}
