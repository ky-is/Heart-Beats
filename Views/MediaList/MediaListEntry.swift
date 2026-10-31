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
			Button(inFavorites ? "Unfavorite" : "Favorite", systemImage: inFavorites ? "star.slash" : "star") {
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
		// Queued after the current song, like the Play Next action
		Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
			play(entry, true)
		}
	}

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	let gridRows = Int(sqrt(Double(4)))

	/// Read as one element: the name, then how many songs
	private var accessibilityLabel: String {
		"\(entry.id), \("song".pluralize(entry.songCount))"
	}

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
				// Room below the artwork's shadow, so it doesn't sit behind the caption and dull it
				VStack(spacing: 10) {
					if largeTitles {
						let key = SubImagesKey(entry: entry, size: subImageSize)
						imageGrid(subImages?.key == key ? subImages?.images ?? [] : [])
							.frame(width: imageWidth, height: imageWidth)
							.background(Color.tertiary)
							.clipShape(RoundedRectangle(cornerRadius: min(24, imageWidth / 6), style: .continuous))
							.shadow(color: .black.opacity(0.25), radius: 4, y: 3)
							.accessibilityHidden(true)
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
							.accessibilityHidden(true)
					}
					HStack(alignment: .lastTextBaseline, spacing: 0) {
						Text(entry.id)
							.font(largeTitles ? .headline : .caption)
							// One line at the default text size and smaller; wraps when larger text would cut it off
							.lineLimit(dynamicTypeSize > .large ? nil : 1)
						Text(" " + String(entry.songCount))
							.foregroundStyle(Color.secondaryText)
							.font(largeTitles ? .subheadline : .caption)
					}
				}
			} else {
				HStack {
					AlbumArt(artist: entry.id, artwork: entry.albumArtwork)
						.accessibilityHidden(true)
					// At accessibility text sizes the count moves under the name, leaving the name the whole width
					if dynamicTypeSize.isAccessibilitySize {
						VStack(alignment: .leading) {
							Text(entry.id)
								.font(.title2)
							Text("song".pluralize(entry.songCount))
								.foregroundStyle(Color.secondaryText)
						}
					} else {
						Text(entry.id)
							.font(.title2)
						Spacer()
						Text(String(entry.songCount))
							.foregroundStyle(Color.secondaryText)
					}
				}
#if targetEnvironment(macCatalyst)
					.padding([.vertical, .trailing], 8)
#endif
			}
		}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(accessibilityLabel)
			.accessibilityAddTraits(.isButton)
			.accessibilityHint("Plays shuffled in Music")
			.modifier(EntryAccessibilityActions(isOn: listViewMode == "grid", content: {
				addToQueueButton
				favoriteButton
			}))
			.contextMenu {
				Button("Shuffle", systemImage: "shuffle") {
					play(entry, false)
				}
				addToQueueButton
				if groupBy != nil {
					Divider()
					favoriteButton
				}
			} preview: {
				if let songs = entry.songs {
					// Its own view, so the album grouping only runs when the preview opens. An artist's songs don't each need its name.
					SongsPreview(songs: songs, showsArtist: groupBy != "artist")
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

/// Queue and favorite as VoiceOver actions, for the grid. A list row already offers its swipe actions there, so it skips these to avoid listing them twice.
private struct EntryAccessibilityActions<Actions: View>: ViewModifier {
	let isOn: Bool
	@ViewBuilder let content: () -> Actions

	func body(content body: Content) -> some View {
		if isOn {
			body.accessibilityActions(content)
		} else {
			body
		}
	}
}

/// The long-press preview: the entry's songs by album, the albums with the most songs first. A preview can't scroll, so each album's songs run together beside its cover, and albums past what fits are counted instead.
private struct SongsPreview: View {
	let songs: [MPMediaItem]
	/// Genres and years mix artists, so each album names its own
	let showsArtist: Bool

	private struct Album: Identifiable {
		let id: MPMediaEntityPersistentID
		let title: String
		let artist: String?
		let artwork: ArtworkCache.Artwork?
		let songs: [MPMediaItem]
	}

	private let coverSize: CGFloat = 56
	private let maximumAlbums = 8

	/// How many songs, how long they run and how often Music has played them
	private var summary: String {
		let seconds = songs.reduce(0) { $0 + $1.playbackDuration }
		let plays = songs.reduce(0) { $0 + $1.playCount }
		let length = seconds >= 60 ? Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)) : nil
		let played: String? = switch plays {
		case 0: nil
		case 1: "played once"
		default: "played \(plays.formatted()) times"
		}
		return ["song".pluralize(songs.count), length, played].compactMap { $0 }.joined(separator: " · ")
	}

	private var albums: [Album] {
		Dictionary(grouping: songs, by: \.artworkID).map { id, songs in
			let songs = songs.sorted { ($0.discNumber, $0.albumTrackNumber) < ($1.discNumber, $1.albumTrackNumber) }
			let first = songs[0]
			return Album(id: id, title: first.albumTitle?.nonEmpty ?? first.title ?? "", artist: first.albumArtist?.nonEmpty ?? first.artist, artwork: songs.lazy.compactMap { ArtworkCache.Artwork(song: $0) }.first, songs: songs)
		}
			.sorted { ($0.songs.count, $1.title) > ($1.songs.count, $0.title) }
	}

	var body: some View {
		let albums = albums
		VStack(alignment: .leading, spacing: 14) {
			Text(summary)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(Color.secondaryText)
			ForEach(albums.prefix(maximumAlbums)) { album in
				HStack(alignment: .top, spacing: 12) {
					AlbumArt(artist: "", artwork: album.artwork, displayWidth: coverSize)
					VStack(alignment: .leading, spacing: 2) {
						Text(showsArtist ? [album.title, album.artist].compactMap { $0 }.joined(separator: " · ") : album.title)
							.font(.headline)
							.lineLimit(1)
						Text(album.songs.map { $0.title?.nonEmpty ?? "Untitled" }.joined(separator: " · "))
							.font(.subheadline)
							.foregroundStyle(Color.secondaryText)
							.lineLimit(4)
					}
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			if albums.count > maximumAlbums {
				let rest = albums.dropFirst(maximumAlbums)
				Text("\("more album".pluralize(rest.count)), \("song".pluralize(rest.reduce(0) { $0 + $1.songs.count }))")
					.font(.subheadline)
					.foregroundStyle(Color.secondaryText)
					.padding(.leading, coverSize + 12)
			}
		}
			.padding(16)
			.frame(width: 360, alignment: .leading)
			.fixedSize(horizontal: false, vertical: true)
	}
}

private extension String {
	var nonEmpty: String? {
		isEmpty ? nil : self
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
