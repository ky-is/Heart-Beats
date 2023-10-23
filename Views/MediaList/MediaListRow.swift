import SwiftUI
import MediaPlayer

struct MediaListRow: View {
	let entry: MediaEntry
	let imageWidth: Int
	let inFavorites: Bool
	let play: (MediaEntry, Bool) -> Void

	private let displayWidth: CGFloat = 80

	private var favoriteButton: some View {
		Button(inFavorites ? "Unfavorite" : "Favorite", systemImage: inFavorites ? "star" : "star.fill") {
			var favorites = SyncStorage.shared.currentFavorites
			if inFavorites {
				favorites = favorites.filter { $0 != entry.id}
			} else {
				favorites.append(entry.id)
			}
			withAnimation {
				if SyncStorage.shared.showGenres {
					SyncStorage.shared.favoritedGenres = favorites
				} else {
					SyncStorage.shared.favorited = favorites
				}
			}
		}
	}

	private var addToQueueButton: some View {
		Button("Add to queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
			play(entry, true)
		}
	}

	var body: some View {
		HStack {
			Group {
				if let image = entry.artwork?.image(at: CGSize(width: imageWidth, height: imageWidth)) {
					Image(uiImage: image)
						.resizable()
//#if DEBUG
//						.blur(radius: SCREENSHOT_MODE ? 10 : 0) //SAMPLE
//#endif
				} else {
					Rectangle()
						.foregroundStyle(.tertiary)
						.overlay {
							Image(systemName: "music.note.list")
								.foregroundStyle(.background)
								.font(.system(size: displayWidth * (2 / 3)))
						}
							.unredacted()
				}
			}
				.frame(width: displayWidth, height: displayWidth)
				.clipShape(RoundedRectangle(cornerRadius: displayWidth / 6, style: .continuous))
			Text(entry.id)
				.font(.title2)
			Spacer()
			Text(String(entry.songCount))
				.foregroundStyle(.secondary)
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
									if let image = $0.image(at: CGSize(width: previewSize, height: previewSize)) {
										Image(uiImage: image)
											.resizable()
											.aspectRatio(1, contentMode: .fill)
											.frame(width: previewSize, height: previewSize)
											.clipShape(RoundedRectangle(cornerRadius: previewSize / 6, style: .continuous))
											.padding(.horizontal, 8)
										Spacer()
									}
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
		MediaListRow(entry: MediaCollection.screenshotData[0], imageWidth: 128, inFavorites: true, play: { _, _ in })
	}
		.listStyle(.plain)
		.fontDesign(.rounded)
}
