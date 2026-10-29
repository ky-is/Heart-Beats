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

	private var subImageSize: CGFloat {
		imageWidth / Double(gridRows)
	}

	/// The Years grid's album covers, decoded off the main thread once the scan has loaded the songs
	@State private var subImages: (key: SubImagesKey, images: [UIImage])?

	private struct SubImagesKey: Equatable {
		let entry: MediaEntry
		let size: CGFloat
	}

	private func imageGrid(_ subImages: [UIImage]) -> some View {
		let subSize = subImageSize
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
						let key = SubImagesKey(entry: entry, size: subImageSize)
						imageGrid(subImages?.key == key ? subImages?.images ?? [] : [])
							.frame(width: imageWidth, height: imageWidth)
							.background(Color.tertiary)
							.clipShape(RoundedRectangle(cornerRadius: min(24, imageWidth / 6), style: .continuous))
							.shadow(color: .black.opacity(0.25), radius: 4, y: 3)
							.task(id: key) {
#if targetEnvironment(simulator) || DEBUG
								// The sample years have no songs, so they show the sample covers
								if SampleLibrary.isOn && entry.songs == nil {
									subImages = (key, MediaEntry.screenshotCovers(forYear: entry.id, count: gridRows * gridRows))
									return
								}
#endif
								guard entry.songs != nil else { return }
								let images = await ArtworkCache.albumImages(for: entry, size: AlbumArt.pixelSize(forWidth: key.size), count: gridRows * gridRows)
								guard !Task.isCancelled else { return }
								subImages = (key, images)
							}
					} else {
						AlbumArt(artist: entry.id, artwork: entry.albumArtwork, displayWidth: imageWidth)
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
					AlbumArt(artist: entry.id, artwork: entry.albumArtwork)
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
					// Its own view, so the album grouping only runs when the preview opens
					SongsPreview(songs: songs)
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

/// The long-press preview: the entry's songs beside one cover per album.
private struct SongsPreview: View {
	let songs: [MPMediaItem]

	private let previewSize: CGFloat = 80

	var body: some View {
		let albumArtworks = Dictionary(grouping: songs, by: \.artworkID).values.compactMap { songs in songs.lazy.compactMap { ArtworkCache.Artwork(song: $0) }.first }
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
					ForEach(albumArtworks, id: \.self) {
						AlbumArt(artist: "", artwork: $0, displayWidth: previewSize)
							.padding(.horizontal, 8)
						Spacer()
					}
				}
			}
	}
}

#Preview {
	NavigationStack {
		List {
			MediaListEntry(groupBy: "artist", listViewMode: "list", largeTitles: false, entry: MediaEntry.screenshotData[0], imageWidth: 88, inFavorites: true, play: { _, _ in })
			MediaListEntry(groupBy: "artist", listViewMode: "list", largeTitles: false, entry: MediaEntry.screenshotData[1], imageWidth: 88, inFavorites: true, play: { _, _ in })
			MediaListEntry(groupBy: "artist", listViewMode: "grid", largeTitles: false, entry: MediaEntry.screenshotData[0], imageWidth: 88, inFavorites: true, play: { _, _ in })
		}
			.listStyle(.plain)
	}
		.fontDesign(.rounded)
}
