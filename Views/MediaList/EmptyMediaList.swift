import SwiftUI

struct EmptyMediaList: View {
	var collection: MediaCollection
	var imageWidth: Int

	private let play: (MediaEntry) -> Void = { _ in }

	var body: some View {
		if (collection.groupBy == "genre" ? SyncStorage.shared.cachedGenres : SyncStorage.shared.cachedArtists) == nil {
			List {
				ForEach(MediaCollection.screenshotData) {
					MediaListRow(entry: $0, imageWidth: imageWidth, inFavorites: false, play: play)
				}
			}
				.listStyle(.plain)
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
		EmptyMediaList(collection: MediaCollection(groupBy: "artist"), imageWidth: 128)
	}
		.fontDesign(.rounded)
}