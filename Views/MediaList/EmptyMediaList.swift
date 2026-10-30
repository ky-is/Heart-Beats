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
			List {
				Section {} footer: {
					Text("No 5-star songs found in your library…")
						.font(.title)
						.multilineTextAlignment(.center)
						.padding(.top)
						.padding(.horizontal)
				}

				Section {
					Link(destination: URL(string: "App-prefs:MUSIC")!) {
						Label("Settings > Music >\nEnable \"Show Star Ratings\"", systemImage: "gear.circle.fill")
					}
						.accessibilityLabel("Open Settings, then Music, and turn on Show Star Ratings")
				} header: {
					SectionTitle("Step 1: Ensure star ratings are enabled")
				}
				Section {
					Link(destination: URL(string: "audio-player-event:")!) {
						Label("Open Music App to rate", systemImage: "music.note.house.fill")
					}
				} header: {
					SectionTitle("Step 2: Rate songs in Music app")
				}
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
