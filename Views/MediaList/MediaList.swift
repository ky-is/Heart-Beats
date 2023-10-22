import SwiftUI
import MediaPlayer

struct MediaList: View {
	var collection: MediaCollection

	@Environment(\.scenePhase) private var scenePhase
	@State private var selection: MediaEntry?
	@EnvironmentObject private var syncStorage: SyncStorage

	private let imageWidth = 128

	private func play(entry: MediaEntry) {
		guard let songs = entry.songs else { return }

		Task { @MainActor in
			let entryName = entry.id
			let played = SyncStorage.shared.currentPlayed
			if !played.contains(entryName) {
				var favorites = SyncStorage.shared.currentFavorites
				if favorites.count < 3 {
					favorites.append(entryName)
					if SyncStorage.shared.showGenres {
						SyncStorage.shared.favoritedGenres = favorites
					} else {
						SyncStorage.shared.favorited = favorites
					}
				}
				if SyncStorage.shared.showGenres {
					SyncStorage.shared.playedGenres.append(entryName)
				} else {
					SyncStorage.shared.played.append(entryName)
				}
			}
		}

		Task {
			let player = MPMusicPlayerController.systemMusicPlayer
			player.setQueue(with: songs)
			player.shuffleMode = .songs
			player.play()
			await openMusicApp()
		}
	}

	private func openMusicApp() async {
		if let url = URL(string: "audio-player-event:"), UIApplication.shared.canOpenURL(url) {
			Task { @MainActor in
				await UIApplication.shared.open(url)
			}
		} else {
			print("Unable to open Music.app")
			//TODO macOS
		}
	}

	private var groupedEntries: [[MediaEntry]] {
		let favorites = UserDefaults.standard.showGenres ? UserDefaults.standard.favoritedGenres : UserDefaults.standard.favorited
		var favoriteEntries: [MediaEntry] = []
		var nonfavoriteEntries: [MediaEntry] = []
		for entry in collection.entries {
			if favorites.contains(entry.id) {
				favoriteEntries.append(entry)
			} else {
				nonfavoriteEntries.append(entry)
			}
		}
		return favoriteEntries.isEmpty ? [nonfavoriteEntries] : [favoriteEntries, nonfavoriteEntries]
	}

	private func showHeaders(allEntriesGroups: [[MediaEntry]]) -> Bool {
#if DEBUG
		if SCREENSHOT_MODE {
			return false
		}
#endif
		return allEntriesGroups.count > 1
	}

	private var navigationTitle: String {
		var count = collection.entries.count
#if DEBUG
		if SCREENSHOT_MODE {
			count = 42
		}
#endif
		return collection.groupBy.capitalized.pluralize(count)
	}

	var body: some View {
		let activeSelection = Binding {
			selection
		} set: { newValue in
			withAnimation {
				selection = newValue
			}
			if let newValue {
				play(entry: newValue)
			}
		}
//		let allEntriesGroups: [[MediaEntry]] = [[]] //SAMPLE
		let allEntriesGroups = groupedEntries
		let hasEntries = !allEntriesGroups[0].isEmpty
		let showHeaders = showHeaders(allEntriesGroups: allEntriesGroups)
		Group {
			if !hasEntries {
				EmptyMediaList(collection: collection, imageWidth: imageWidth)
			} else {
				List(selection: activeSelection) {
					ForEach(allEntriesGroups, id: \.self) { groupEntries in
						let inFavorites = showHeaders && groupEntries == allEntriesGroups[0]
						Section {
							ForEach(groupEntries) { entry in
								MediaListRow(entry: entry, imageWidth: imageWidth, inFavorites: inFavorites, play: play)
									.tag(entry)
							}
						} header: {
							if showHeaders {
								Text(inFavorites ? "Favorites" : "Uncategorized")
									.font(.headline.smallCaps())
							}
						}
					}
				}
					.listStyle(.plain)
			}
		}
			.navigationTitle(navigationTitle)
			.onChange(of: scenePhase) { _, newPhase in
				if newPhase == .active {
					withAnimation {
						selection = nil
					}
				}
			}
	}
}

#Preview {
	NavigationStack {
		MediaList(collection: MediaCollection(groupBy: "artist"))
	}
		.fontDesign(.rounded)
}
