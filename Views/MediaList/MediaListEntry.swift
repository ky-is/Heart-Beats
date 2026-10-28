import SwiftUI
import MediaPlayer

struct MediaListEntry: View {
	/// "artist" or "genre"; nil for years, which have no favorites
	let groupBy: String?
	let listViewMode: String
	let largeTitles: Bool
	let entry: MediaEntry
	let imageWidth: CGFloat
	let inFavorites: Bool
	let play: (MediaEntry, Bool) -> Void

	@ViewBuilder
	private var favoriteButton: some View {
		if let groupBy {
			Button(inFavorites ? "Unfavorite" : "Favorite", systemImage: inFavorites ? "star" : "star.fill") {
				var favorites = UserDefaults.standard.favorites(for: groupBy)
				if inFavorites {
					favorites.removeAll { $0.normalized() == entry.id.normalized() }
				} else {
					favorites.append(entry.id)
				}
				// The sync observer rescans the collection after this write
				UserDefaults.standard.setFavorites(favorites, for: groupBy)
			}
		}
	}

	private var addToQueueButton: some View {
		Button("Add to queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
			play(entry, true)
		}
	}

	let gridRows = Int(sqrt(Double(4)))

	private var subImages: [UIImage] {
		let subSize = imageWidth / Double(gridRows)
		var images: [UIImage] = []
		var albumsIDs: [String] = []
		if let songs = entry.songs {
			let gridCount = Int(pow(Double(gridRows), 2))
			for song in songs {
				guard let artwork = song.artwork else { continue }
				let albumID = (song.albumTitle ?? "") + (song.artist ?? "")
				if !albumsIDs.contains(albumID), let image = ArtworkCache.image(for: artwork, size: subSize) {
					albumsIDs.append(albumID)
					images.append(image)
					if images.count >= gridCount {
						break
					}
				}
			}
		}
		return images
	}

	private func imageGrid(_ subImages: [UIImage]) -> some View {
		let subSize = imageWidth / Double(gridRows)
		return Grid(horizontalSpacing: 0, verticalSpacing: 0) {
			ForEach(Array(0..<gridRows), id: \.self) { rowIndex in
				GridRow {
					ForEach(Array(0..<gridRows), id: \.self) {
						let index = rowIndex * gridRows + $0
						if index < subImages.count {
							Image(uiImage: subImages[index])
								.resizable()
								.frame(width: subSize, height: subSize)
						}
					}
				}
			}
		}
	}

	var body: some View {
		Group {
			if listViewMode == "grid" {
				VStack {
					if largeTitles {
						imageGrid(subImages)
							.frame(width: imageWidth, height: imageWidth)
							.background(Color.tertiary)
							.clipShape(RoundedRectangle(cornerRadius: min(24, imageWidth / 6), style: .continuous))
							.shadow(color: .black.opacity(0.25), radius: 4, y: 3)
					} else {
						AlbumArt(artist: entry.id, artwork: entry.artwork, displayWidth: imageWidth)
					}
					HStack(alignment: .lastTextBaseline, spacing: 0) {
						Text(entry.id)
							.font(largeTitles ? .headline : .caption)
							.lineLimit(1)
						Text(" " + String(entry.songCount))
							.foregroundStyle(Color.secondary)
							.font(largeTitles ? .subheadline : .caption)
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
#if targetEnvironment(macCatalyst)
					.padding([.vertical, .trailing], 8)
#endif
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
	NavigationStack {
		List {
			MediaListEntry(groupBy: "artist", listViewMode: "list", largeTitles: false, entry: GroupedCollection.screenshotData[0], imageWidth: 88, inFavorites: true, play: { _, _ in })
			MediaListEntry(groupBy: "artist", listViewMode: "list", largeTitles: false, entry: GroupedCollection.screenshotData[1], imageWidth: 88, inFavorites: true, play: { _, _ in })
			MediaListEntry(groupBy: "artist", listViewMode: "grid", largeTitles: false, entry: GroupedCollection.screenshotData[0], imageWidth: 88, inFavorites: true, play: { _, _ in })
		}
			.listStyle(.plain)
	}
		.fontDesign(.rounded)
}
