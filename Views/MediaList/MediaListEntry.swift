import SwiftUI

struct MediaListEntry: View {
	let listViewMode: String
	let entry: MediaEntry
	let imageWidth: CGFloat
	let inFavorites: Bool
	let play: (MediaEntry, Bool) -> Void

	private var favoriteButton: some View {
		Button(inFavorites ? "Unfavorite" : "Favorite", systemImage: inFavorites ? "star" : "star.fill") {
			var favorites = UserDefaults.standard.currentFavorites
			if inFavorites {
				favorites = favorites.filter { $0 != entry.id}
			} else {
				favorites.append(entry.id)
			}
			withAnimation {
				UserDefaults.standard.currentFavorites = favorites
			}
		}
	}

	private var addToQueueButton: some View {
		Button("Add to queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
			play(entry, true)
		}
	}

	var body: some View {
		Group {
			if listViewMode == "grid" {
				VStack {
					AlbumArt(artist: entry.id, artwork: entry.artwork, displayWidth: imageWidth)
					HStack(spacing: 0) {
						Text(entry.id)
							.font(.caption)
							.lineLimit(1)
						Text(" " + String(entry.songCount))
							.foregroundStyle(Color.secondary)
							.font(.caption)
					}
				}
			} else {
				HStack {
					AlbumArt(artist: entry.id, artwork: entry.artwork)
					Text(entry.id)
						.font(.title2)
					Spacer()
					Text(String(entry.songCount))
						.foregroundStyle(Color.secondary)
				}
			}
		}
			.contextMenu {
				addToQueueButton
				Button("Play", systemImage: "shuffle") {
					play(entry, false)
				}
				favoriteButton
			} preview: {
				if let songs = entry.songs {
					let previewSize: CGFloat = 80
					let a = Dictionary(grouping: songs, by: { $0.albumPersistentID }).values.compactMap { songs in songs.first(where: { $0.artwork != nil })?.artwork }
					List(songs, id: \.self) {
						if let title = $0.title {
							Text(title)
								.padding(.leading, previewSize)
								.lineLimit(1)
						}
					}
						.listStyle(.plain)
						.overlay(alignment: .leading) {
							VStack(spacing: 0) {
								Spacer()
								ForEach(a, id: \.self) {
									AlbumArt(artist: "", artwork: $0, displayWidth: previewSize)
										.padding(.horizontal, 8)
									Spacer()
								}
							}
						}
				}
			}
			.swipeActions {
				if entry.songs != nil {
					favoriteButton
						.tint(.yellow)
					addToQueueButton
						.tint(.blue)
				}
			}
	}
}

#Preview {
	List {
		MediaListEntry(listViewMode: "grid", entry: MediaCollection.screenshotData[0], imageWidth: 88, inFavorites: true, play: { _, _ in })
	}
		.listStyle(.plain)
		.fontDesign(.rounded)
}
